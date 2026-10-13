import ExchangeFormat
import Foundation
@testable import ReaderAuthentication
import Testing
import X509

@Suite("ReaderAuthenticationVerifier Tests")
struct ReaderAuthenticationVerifierTests {

    private static let mdl = "org.iso.18013.5.1.mDL"
    private static let aamva = "org.iso.18013.5.1.aamva"
    private static let photoID = "org.iso.23220.photoID.1"
    private static let supported: Set<String> = [mdl]
    private static let transcript = Data([0x80])

    private func makeRequest(
        encoded: Data,
        supported: Set<String> = ReaderAuthenticationVerifierTests.supported,
        roots: [Certificate] = [ReaderAuthFixtures.testCertificate()]
    ) -> ReaderAuthenticationVerificationRequest {
        ReaderAuthenticationVerificationRequest(
            encodedDeviceRequest: encoded,
            untaggedSessionTranscriptBytes: Self.transcript,
            trustedReaderCertificates: roots,
            supportedDocumentTypes: supported
        )
    }

    // MARK: - AC1: malformed request fails before candidate work

    @Test("AC1: undecodable bytes throw malformedDeviceRequest and no candidate is evaluated")
    func malformedBytesThrowBeforeCandidates() async throws {
        // Trailing garbage after a complete top-level item -> decode fails.
        let valid = ReaderAuthFixtures.encodedDeviceRequest(docTypes: [Self.mdl])
        let corrupted = valid + Data([0xFF])
        let authenticator = MockReaderAuthenticator(outcomes: [:])
        let sut = ReaderAuthenticationVerifier(candidateAuthenticator: authenticator)

        await #expect(throws: ReaderAuthenticationFailure.malformedDeviceRequest) {
            _ = try await sut.authenticateDeviceRequest(makeRequest(encoded: corrupted))
        }
        #expect(authenticator.evaluatedDocTypes.isEmpty)
    }

    // MARK: - AC2: no supported candidate -> unfulfillable

    @Test("AC2: no supported document type returns unfulfillable without verifying any candidate")
    func noSupportedCandidateReturnsUnfulfillable() async throws {
        let encoded = ReaderAuthFixtures.encodedDeviceRequest(docTypes: [Self.aamva, Self.photoID])
        let authenticator = MockReaderAuthenticator(outcomes: [:])
        let sut = ReaderAuthenticationVerifier(candidateAuthenticator: authenticator)

        let outcome = try await sut.authenticateDeviceRequest(makeRequest(encoded: encoded))

        #expect(outcome == .unfulfillable)
        #expect(authenticator.evaluatedDocTypes.isEmpty)
    }

    // MARK: - AC3: first candidate passing both stages is selected

    @Test("AC3: returns the first candidate passing both stages and does not evaluate later ones")
    func firstPassingCandidateSelectedAndStops() async throws {
        // Supported candidates A, B, C, D in order (all mDL so all supported).
        // A fails R4 (invalid signature); B passes R4 but fails R5 (no SIA leaf);
        // C and D would pass both. Expect C selected, D never evaluated.
        let leafWithSIA = try ReaderAuthFixtures.leafCertificate()           // passes R5
        let leafNoSIA = try ReaderAuthFixtures.leafCertificate(siaEntries: nil) // fails R5

        // All four candidates share docType mDL, so key the mock by a per-call
        // sequence instead: use distinct docTypes but mark all supported.
        let a = "doc.A", b = "doc.B", c = "doc.C", d = "doc.D"
        let encoded = ReaderAuthFixtures.encodedDeviceRequest(docTypes: [a, b, c, d])
        let authenticator = MockReaderAuthenticator(outcomes: [
            a: .throwR4(.invalidReaderSignature),
            b: .verified(leaf: leafNoSIA),
            c: .verified(leaf: leafWithSIA),
            d: .verified(leaf: leafWithSIA)
        ])
        let sut = ReaderAuthenticationVerifier(candidateAuthenticator: authenticator)

        let outcome = try await sut.authenticateDeviceRequest(
            makeRequest(encoded: encoded, supported: [a, b, c, d])
        )

        guard case .authenticated(let request) = outcome else {
            Issue.record("Expected .authenticated outcome, got \(outcome)")
            return
        }
        #expect(request.docRequest.itemsRequest.docType == c)
        // A, B, C evaluated; D must not be.
        #expect(authenticator.evaluatedDocTypes == [a, b, c])
    }

    // MARK: - AC4: every candidate fails -> throw the last candidate's failure

    @Test("AC4: when every candidate fails, throws the final candidate's failure")
    func allCandidatesFailThrowsLastFailure() async throws {
        let a = "doc.A", b = "doc.B"
        let leafNoSIA = try ReaderAuthFixtures.leafCertificate(siaEntries: nil)
        let encoded = ReaderAuthFixtures.encodedDeviceRequest(docTypes: [a, b])
        // A fails R4 invalidReaderSignature; B passes R4 then fails R5
        // privacyPolicyURLInvalid. Final (B's) failure must be thrown.
        let authenticator = MockReaderAuthenticator(outcomes: [
            a: .throwR4(.invalidReaderSignature),
            b: .verified(leaf: leafNoSIA)
        ])
        let sut = ReaderAuthenticationVerifier(candidateAuthenticator: authenticator)

        await #expect(throws: ReaderAuthenticationFailure.privacyPolicyURLInvalid) {
            _ = try await sut.authenticateDeviceRequest(
                makeRequest(encoded: encoded, supported: [a, b])
            )
        }
        #expect(authenticator.evaluatedDocTypes == [a, b])
    }

    // MARK: - AC6: authenticates through either configured root (no root identity returned)

    @Test("AC6: a passing candidate authenticates with multiple configured roots and reveals no root")
    func authenticatesWithMultipleRootsNoRootIdentity() async throws {
        let leafWithSIA = try ReaderAuthFixtures.leafCertificate()
        let encoded = ReaderAuthFixtures.encodedDeviceRequest(docTypes: [Self.mdl])
        let authenticator = MockReaderAuthenticator(outcomes: [Self.mdl: .verified(leaf: leafWithSIA)])
        let sut = ReaderAuthenticationVerifier(candidateAuthenticator: authenticator)

        // Two configured roots; the outcome carries no root identity by type.
        let roots = [ReaderAuthFixtures.testCertificate(), ReaderAuthFixtures.testCertificate()]
        let outcome = try await sut.authenticateDeviceRequest(
            makeRequest(encoded: encoded, roots: roots)
        )

        guard case .authenticated(let request) = outcome else {
            Issue.record("Expected .authenticated outcome, got \(outcome)")
            return
        }
        #expect(request.docRequest.itemsRequest.docType == Self.mdl)
    }

    // MARK: - AC7: untrusted reader surfaces untrustedReaderCertificate

    @Test("AC7: an untrusted reader throws untrustedReaderCertificate and selects nothing")
    func untrustedReaderThrows() async throws {
        let encoded = ReaderAuthFixtures.encodedDeviceRequest(docTypes: [Self.mdl])
        let authenticator = MockReaderAuthenticator(outcomes: [
            Self.mdl: .throwR4(.untrustedReaderCertificate)
        ])
        let sut = ReaderAuthenticationVerifier(candidateAuthenticator: authenticator)

        await #expect(throws: ReaderAuthenticationFailure.untrustedReaderCertificate) {
            _ = try await sut.authenticateDeviceRequest(makeRequest(encoded: encoded))
        }
    }

    // MARK: - Supported-type filtering preserves order and ignores unsupported

    @Test("only supported candidates are evaluated, in input order")
    func onlySupportedCandidatesEvaluatedInOrder() async throws {
        let leafWithSIA = try ReaderAuthFixtures.leafCertificate()
        // Order: unsupported, supported-fail, supported-pass. Unsupported skipped.
        let encoded = ReaderAuthFixtures.encodedDeviceRequest(
            docTypes: [Self.aamva, "doc.X", "doc.Y"]
        )
        let authenticator = MockReaderAuthenticator(outcomes: [
            "doc.X": .throwR4(.invalidReaderSignature),
            "doc.Y": .verified(leaf: leafWithSIA)
        ])
        let sut = ReaderAuthenticationVerifier(candidateAuthenticator: authenticator)

        let outcome = try await sut.authenticateDeviceRequest(
            makeRequest(encoded: encoded, supported: ["doc.X", "doc.Y"])
        )

        guard case .authenticated(let request) = outcome else {
            Issue.record("Expected .authenticated outcome, got \(outcome)")
            return
        }
        #expect(request.docRequest.itemsRequest.docType == "doc.Y")
        // aamva is unsupported and must not be evaluated.
        #expect(authenticator.evaluatedDocTypes == ["doc.X", "doc.Y"])
    }
}
