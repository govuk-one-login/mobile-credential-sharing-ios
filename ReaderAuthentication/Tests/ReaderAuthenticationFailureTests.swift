import Foundation
@testable import ReaderAuthentication
import Testing

@Suite("ReaderAuthenticationFailure Tests")
struct ReaderAuthenticationFailureTests {

    private struct RootCause: Error {}

    @Test("stores reason and derives message, with no cause by default")
    func storesReasonAndMessage() {
        let failure = ReaderAuthenticationFailure(reason: .readerAuthMissing)

        #expect(failure.reason == .readerAuthMissing)
        #expect(failure.message == "Reader Authentication failed with reason: readerAuthMissing")
        #expect(failure.cause == nil)
    }

    @Test("stores the underlying cause when provided")
    func storesCause() {
        let cause = RootCause()
        let failure = ReaderAuthenticationFailure(
            reason: .invalidReaderSignature,
            cause: cause
        )

        #expect(failure.reason == .invalidReaderSignature)
        #expect(failure.cause is RootCause)
    }

    @Test("is throwable and catchable as its own type")
    func isThrowable() {
        #expect(throws: ReaderAuthenticationFailure.self) {
            throw ReaderAuthenticationFailure(reason: .untrustedReaderCertificate)
        }
    }

    @Test("equality is defined by reason, independent of cause")
    func equalityByReason() {
        let a = ReaderAuthenticationFailure(reason: .malformedReaderAuth)
        let b = ReaderAuthenticationFailure(reason: .malformedReaderAuth, cause: RootCause())
        let c = ReaderAuthenticationFailure(reason: .invalidReaderSignature)

        #expect(a == b)
        #expect(a != c)
    }
}
