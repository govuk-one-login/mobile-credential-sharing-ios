import CryptoKit
import Foundation
@testable import SharingSecurity
import Testing

@Suite
struct SessionSecurityTests {
    let privateKey = P256.KeyAgreement.PrivateKey()
    var sut: SessionDecryption {
        SessionDecryption(privateKey: privateKey)
    }
    
    @Test("Public key matches private key")
    func publicKeyValue() async throws {
        #expect(sut.publicKey.rawRepresentation == privateKey.publicKey.rawRepresentation)
    }
}
