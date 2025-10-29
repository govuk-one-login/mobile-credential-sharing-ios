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

final public class SessionDecryption: SessionSecurity {
    public let privateKey: P256.KeyAgreement.PrivateKey
    
    public var publicKey: P256.KeyAgreement.PublicKey {
        privateKey.publicKey
    }
    
    public convenience init() {
        self.init(privateKey: .init())
    }
    
    init(privateKey: P256.KeyAgreement.PrivateKey = .init()) {
        self.privateKey = privateKey
    }
    
    func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        Data()
    }
}
