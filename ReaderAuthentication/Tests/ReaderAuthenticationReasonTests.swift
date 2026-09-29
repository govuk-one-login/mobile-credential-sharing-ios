@testable import ReaderAuthentication
import Testing

@Suite("ReaderAuthenticationReason Tests")
struct ReaderAuthenticationReasonTests {

    @Test("has all expected reason cases")
    func hasAllExpectedCases() {
        let expected: Set<ReaderAuthenticationReason> = [
            .readerAuthMissing,
            .invalidReaderSignature,
            .malformedReaderAuth,
            .unsupportedReaderAuthAlgorithm,
            .untrustedReaderCertificate,
            .privacyPolicyURLInvalid,
            .malformedDeviceRequest
        ]

        #expect(Set(ReaderAuthenticationReason.allCases) == expected)
        #expect(ReaderAuthenticationReason.allCases.count == 7)
    }

    @Test("each case is exhaustively matchable")
    func exhaustiveSwitch() {
        for reason in ReaderAuthenticationReason.allCases {
            switch reason {
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
