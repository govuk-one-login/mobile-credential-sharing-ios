import CryptoKit
import Foundation
import SharingCryptoService

class MockSessionDecryption: Decryption {
    var skDeviceKey: [UInt8]?
    
    var publicKey: P256.KeyAgreement.PublicKey = P256.KeyAgreement.PrivateKey().publicKey
    var decryptedDataToReturn = Data()
    var computeSharedSecretError: (any Error)?
    
    func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        messageCounter: Int,
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        skDeviceKey = [0, 1]
        return decryptedDataToReturn
    }

    func computeSharedSecret(using eDeviceKey: COSEKey) throws -> SharedSecret {
        if let computeSharedSecretError {
            throw computeSharedSecretError
        }
        let privateKey = P256.KeyAgreement.PrivateKey()
        return try privateKey.sharedSecretFromKeyAgreement(with: P256.KeyAgreement.PrivateKey().publicKey)
    }
}
