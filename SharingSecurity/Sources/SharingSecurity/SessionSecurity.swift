import CryptoKit
import Foundation

protocol SessionSecurity {
    var publicKey: P256.KeyAgreement.PublicKey { get }

    func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: EncryptionParameters
    ) throws -> Data
}

protocol EncryptionParameters {
    var sharedInfo: Data { get }
    var identifier: Data { get }
}
