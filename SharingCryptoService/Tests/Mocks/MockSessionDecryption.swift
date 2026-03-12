import CryptoKit
import SharingCryptoService
import Foundation

class MockSessionDecryption: Decryption {
    var publicKey: P256.KeyAgreement.PublicKey = P256.KeyAgreement.PrivateKey().publicKey
    var decryptedDataToReturn = Data()
    
    func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        return decryptedDataToReturn
    }
}
