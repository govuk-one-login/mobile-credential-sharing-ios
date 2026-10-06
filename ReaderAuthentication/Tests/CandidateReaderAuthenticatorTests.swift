import Foundation
import Testing
@testable import ReaderAuthentication

@Suite("CandidateReaderAuthenticator Tests")
struct CandidateReaderAuthenticatorTests {

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
}
