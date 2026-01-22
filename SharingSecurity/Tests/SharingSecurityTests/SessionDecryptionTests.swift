import CryptoKit
import Foundation
@testable import SharingSecurity
import Testing

@Suite
struct SessionDecryptionTests {
    let privateKey = P256.KeyAgreement.PrivateKey()
    var sut: SessionDecryption {
        SessionDecryption(privateKey: privateKey)
    }
    
    @Test("Public key matches private key")
    func publicKeyValue() async throws {
        #expect(sut.publicKey.rawRepresentation == privateKey.publicKey.rawRepresentation)
    }
    
    @Test("decryptData func generates sharedSecret - does not throw")
    func decryptDataGeneratesSharedSecret() throws {
        let otherPublicKey = P256.KeyAgreement.PrivateKey().publicKey
        #expect(throws: Never.self) {
            try sut.decryptData(
                [0x00],
                salt: [0x00],
                encryptedWith: otherPublicKey,
                by: .reader
            )
        }
    }
}
