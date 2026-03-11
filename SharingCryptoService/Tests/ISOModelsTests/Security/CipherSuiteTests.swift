@testable import CryptoService
import Testing

struct CipherSuiteTests {

    @Test("ISO 18013-5 Cipher Suite has identifier 1")
    func iso180135() {
        #expect(CipherSuite.iso18013.identifier == 1)
    }
}
