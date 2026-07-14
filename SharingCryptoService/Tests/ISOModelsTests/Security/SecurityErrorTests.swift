@testable import SharingCryptoService
import Testing

@Suite("SecurityError errorDescription tests")
struct SecurityErrorTests {
    @Test("securityFormatError returns correct description")
    func securityFormatErrorDescription() {
        let error = SecurityError.securityFormatError
        #expect(error.errorDescription == "The security array didn't contain both a cypher suite and key")
    }

    @Test("cannotDecode returns correct description")
    func cannotDecodeErrorDescription() {
        let error = SecurityError.cannotDecode
        #expect(error.errorDescription == "Cannot decode eDevice key byte array into cbor")
    }
}
