@testable import ReaderAuthentication
import CoseVerification
import Foundation
import Testing
import X509

@Suite("CandidateReaderAuthenticator Tests")
struct CandidateReaderAuthenticatorTests {

    // A non-nil ReaderAuth blob. Its contents are irrelevant to these tests
    // because the injected `MockCoseVerifier` short-circuits the real crypto;
    // it only needs to clear the Step-1 missing-signature guard.
    private static let sampleReaderAuth = Data([0x84, 0x40, 0xA0, 0xF6])

    // A well-formed untagged session transcript (an empty CBOR array), enough
    // for `ReaderAuthenticationBytes` to assemble a payload successfully.
    private static let validTranscript = Data([0x80])

    // MARK: - Missing ReaderAuth throws one typed request failure

    @Test("throws readerAuthMissing when the candidate has no ReaderAuth")
    func missingReaderAuthThrowsTypedFailure() async throws {
        let candidate = try ReaderAuthFixtures.requestedDocument(rawReaderAuth: nil)
        let authenticator = CandidateReaderAuthenticator()

        await #expect(throws: ReaderAuthenticationFailure.readerAuthMissing) {
            _ = try await authenticator.verify(
                candidateDocRequest: candidate,
                untaggedSessionTranscriptBytes: Data([0x80]),
                trustedReaderCertificates: [ReaderAuthFixtures.testCertificate()]
            )
        }
    }

    @Test("missing ReaderAuth fails fast even when no trusted certificates are supplied")
    func missingReaderAuthFailsBeforeTouchingCertificates() async throws {
        // The guard runs before payload reconstruction or any certificate-backed
        // verification, so an empty trust list is irrelevant.
        let candidate = try ReaderAuthFixtures.requestedDocument(rawReaderAuth: nil)
        let authenticator = CandidateReaderAuthenticator()

        await #expect(throws: ReaderAuthenticationFailure.readerAuthMissing) {
            _ = try await authenticator.verify(
                candidateDocRequest: candidate,
                untaggedSessionTranscriptBytes: Data(),
                trustedReaderCertificates: []
            )
        }
    }

    // MARK: - Success path (Steps 2–4)

    @Test("returns the verified request paired with the leaf certificate on success")
    func successReturnsVerifiedRequestWithLeafCertificate() async throws {
        let candidate = try ReaderAuthFixtures.requestedDocument(
            rawReaderAuth: Self.sampleReaderAuth
        )
        let leaf = try ReaderAuthFixtures.leafCertificate()
        let verifier = MockCoseVerifier(
            detachedResult: .success(
                CoseVerificationResult(leafCertificate: leaf, payload: nil)
            )
        )
        let authenticator = CandidateReaderAuthenticator(coseVerifier: verifier)

        let result = try await authenticator.verify(
            candidateDocRequest: candidate,
            untaggedSessionTranscriptBytes: Self.validTranscript,
            trustedReaderCertificates: [ReaderAuthFixtures.testCertificate()]
        )

        #expect(result.docRequest == candidate)
        #expect(result.readerCertificate == leaf)
    }

    // MARK: - Malformed payload (Step 2)

    @Test("maps a payload-assembly failure to malformedReaderAuth without calling the verifier")
    func malformedPayloadThrowsMalformedReaderAuth() async throws {
        // An empty transcript makes ReaderAuthenticationBytes assembly fail, so
        // Step 2 throws before the verifier is ever consulted.
        let candidate = try ReaderAuthFixtures.requestedDocument(
            rawReaderAuth: Self.sampleReaderAuth
        )
        let verifier = MockCoseVerifier(
            detachedResult: .failure(.invalidSignature)
        )
        let authenticator = CandidateReaderAuthenticator(coseVerifier: verifier)

        await #expect(throws: ReaderAuthenticationFailure.malformedReaderAuth) {
            _ = try await authenticator.verify(
                candidateDocRequest: candidate,
                untaggedSessionTranscriptBytes: Data(),
                trustedReaderCertificates: [ReaderAuthFixtures.testCertificate()]
            )
        }
        #expect(verifier.verifyDetachedListCallCount == 0)
    }

    // MARK: - COSE failure mapping (Step 3 / readerFailure)

    @Test(
        "maps each COSE verification failure to its Reader Authentication failure",
        arguments: [
            (CoseVerificationFailure.invalidSignature, ReaderAuthenticationFailure.invalidReaderSignature),
            (.malformedCoseSign1, .malformedReaderAuth),
            (.missingX5Chain, .malformedReaderAuth),
            (.unsupportedAlgorithm, .unsupportedReaderAuthAlgorithm),
            (.untrustedCertificate, .untrustedReaderCertificate),
            (.certificateProfileViolation(reason: "EKU missing"), .untrustedReaderCertificate)
        ]
    )
    func mapsCoseFailureToReaderFailure(
        coseFailure: CoseVerificationFailure,
        expected: ReaderAuthenticationFailure
    ) async throws {
        let candidate = try ReaderAuthFixtures.requestedDocument(
            rawReaderAuth: Self.sampleReaderAuth
        )
        let verifier = MockCoseVerifier(detachedResult: .failure(coseFailure))
        let authenticator = CandidateReaderAuthenticator(coseVerifier: verifier)

        await #expect(throws: expected) {
            _ = try await authenticator.verify(
                candidateDocRequest: candidate,
                untaggedSessionTranscriptBytes: Self.validTranscript,
                trustedReaderCertificates: [ReaderAuthFixtures.testCertificate()]
            )
        }
    }
}
