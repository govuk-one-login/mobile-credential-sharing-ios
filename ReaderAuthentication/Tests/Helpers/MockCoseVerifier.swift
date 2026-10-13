import CoseVerification
import CryptoKit
import Foundation
import X509

/// A configurable `CoseVerifier` test double for `CandidateReaderAuthenticator`
/// tests.
///
/// `CandidateReaderAuthenticator` only ever calls the list-based
/// `verifyDetached(coseSign1Bytes:detachedPayload:trustedRoots:)` overload, so
/// that is the one this mock drives from `detachedResult`. The other protocol
/// requirements are satisfied with trivial stubs that fail loudly if a test ever
/// reaches them unexpectedly.
///
/// Set `detachedResult` to either a canned `CoseVerificationResult` (success) or
/// a `CoseVerificationFailure` (thrown) to exercise each branch of the
/// authenticator's failure mapping and success path. `verifyDetachedListCallCount`
/// lets a test assert the verifier was (or was not) reached.
final class MockCoseVerifier: CoseVerifier, @unchecked Sendable {

    /// The outcome the list-based detached verification should produce.
    enum DetachedOutcome {
        case success(CoseVerificationResult)
        case failure(CoseVerificationFailure)
    }

    var detachedResult: DetachedOutcome

    /// Number of times the list-based detached overload was invoked. Lets a test
    /// assert an earlier step short-circuited before the verifier was called.
    private(set) var verifyDetachedListCallCount = 0

    init(detachedResult: DetachedOutcome) {
        self.detachedResult = detachedResult
    }

    func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        trustedRoots: [Certificate]
    ) async throws -> CoseVerificationResult {
        verifyDetachedListCallCount += 1

        switch detachedResult {
        case .success(let result):
            return result
        case .failure(let failure):
            throw failure
        }
    }

    // MARK: - Unused protocol requirements

    func verifyAttached(
        coseSign1Bytes: Data,
        trustedRoot: Certificate
    ) async throws -> CoseVerificationResult {
        fatalError("verifyAttached is not used by CandidateReaderAuthenticator")
    }

    func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        trustedRoot: Certificate
    ) async throws -> CoseVerificationResult {
        fatalError("single-root verifyDetached is not used by CandidateReaderAuthenticator")
    }

    func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        publicKey: P256.Signing.PublicKey
    ) throws {
        fatalError("key-based verifyDetached is not used by CandidateReaderAuthenticator")
    }
}
