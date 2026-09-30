@testable import ReaderAuthentication
import Testing

@Suite("ReaderAuthenticationFailure Tests")
struct ReaderAuthenticationFailureTests {

    @Test("is throwable and catchable as its own type")
    func isThrowable() {
        #expect(throws: ReaderAuthenticationFailure.self) {
            throw ReaderAuthenticationFailure.untrustedReaderCertificate
        }
    }

    @Test("equality is defined by case")
    func equalityByCase() {
        #expect(ReaderAuthenticationFailure.malformedReaderAuth == .malformedReaderAuth)
        #expect(ReaderAuthenticationFailure.malformedReaderAuth != .invalidReaderSignature)
    }

    @Test("each case is exhaustively matchable")
    func exhaustiveSwitch() {
        let failures: [ReaderAuthenticationFailure] = [
            .readerAuthMissing,
            .invalidReaderSignature,
            .malformedReaderAuth,
            .unsupportedReaderAuthAlgorithm,
            .untrustedReaderCertificate,
            .privacyPolicyURLInvalid,
            .malformedDeviceRequest
        ]

        for failure in failures {
            switch failure {
            case .readerAuthMissing,
                 .invalidReaderSignature,
                 .malformedReaderAuth,
                 .unsupportedReaderAuthAlgorithm,
                 .untrustedReaderCertificate,
                 .privacyPolicyURLInvalid,
                 .malformedDeviceRequest:
                break
            }
        }
    }
}
