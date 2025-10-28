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

final public class SessionDecryption: SessionSecurity {
    public let privateKey: P256.KeyAgreement.PrivateKey
    
    public var publicKey: P256.KeyAgreement.PublicKey {
        privateKey.publicKey
    }
    
    public init(privateKey: P256.KeyAgreement.PrivateKey = .init()) {
        self.privateKey = privateKey
    }
    
    func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        let secret = try privateKey
            .sharedSecretFromKeyAgreement(with: theirPublicKey)
        
        let symmetricKey = secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: parameters.sharedInfo,
            outputByteCount: 32
        )
        
        let nonce = try makeNonce(identifier: parameters.identifier)
        let box = try AES.GCM.SealedBox(combined: Data(nonce) + data)        
        return try AES.GCM.open(box, using: symmetricKey)
    }
    
    private func makeNonce(
        _ counter: UInt32 = 1,
        identifier: Data
    ) throws -> AES.GCM.Nonce {
        var dataNonce = Data()
        dataNonce.append(identifier)
        dataNonce.append(Data(counter.bigEndianByteArray))
        let nonce = try AES.GCM.Nonce(data: dataNonce)
        return nonce
    }
}

extension UInt32 {
    var bigEndianByteArray: [UInt8] {
        withUnsafeBytes(of: bigEndian, Array.init)
    }
}
