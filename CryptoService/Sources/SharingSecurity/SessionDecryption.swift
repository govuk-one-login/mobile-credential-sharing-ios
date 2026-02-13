import CryptoKit
import Foundation

public enum DecryptionError: LocalizedError, Equatable {
    case computeSharedSecretCurve(String)
    case computeSharedSecretMalformedKey(CryptoKitError)

    case skReaderDerivationFailed
    case skDeviceDerivationFailed

    public var errorDescription: String {
        switch self {
        case .computeSharedSecretCurve(let curve):
            return "Error computing shared secret (status code 10) due to EReaderKey.Pub with incompatible curve: \(curve)."
        case .computeSharedSecretMalformedKey(let error):
            return "Error computing shared secret (status code 10) due to malformed EReaderKey.Pub: \(error)."
        case .skReaderDerivationFailed:
            return "SKReader derivation failure (status code 10 encryption error)"
        case .skDeviceDerivationFailed:
            return "SKDevice derivation failure (status code 10 encryption error)"
        }
    }
}

protocol Decryption {
    var publicKey: P256.KeyAgreement.PublicKey { get }

    func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: EncryptionParameters
    ) throws -> Data
}

final public class SessionDecryption: Decryption {
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

    private func calculateSalt(from sessionTranscriptBytes: [UInt8]) -> [UInt8] {
        let digest = SHA256.hash(data: Data(sessionTranscriptBytes))
        return Array(digest)
    }

    private func extractSharedSecretBytes(from sharedSecret: some ContiguousBytes) -> [UInt8] {
        sharedSecret.withUnsafeBytes { Array($0) }
    }

    private func deriveSessionKey(ikm: [UInt8], salt: [UInt8], info: String, length: Int) throws -> [UInt8] {
        let inputKey = SymmetricKey(data: Data(ikm))
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: Data(salt),
            info: Data(info.utf8),
            outputByteCount: length
        )
        return derivedKey.withUnsafeBytes { Array($0) }
    }

    public func deriveSKReader(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) throws -> [UInt8] {
        do {
            let salt = calculateSalt(from: sessionTranscriptBytes)
            let sharedSecretBytes = extractSharedSecretBytes(from: sharedSecret)
            let sessionKey = try deriveSessionKey(
                ikm: sharedSecretBytes,
                salt: salt,
                info: "SKReader",
                length: 32
            )
            print("SKReader key generated")
            return sessionKey
        } catch {
            throw DecryptionError.skReaderDerivationFailed
        }
    }

    public func deriveSKDevice(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) throws -> [UInt8] {
        do {
            let salt = calculateSalt(from: sessionTranscriptBytes)
            let sharedSecretBytes = extractSharedSecretBytes(from: sharedSecret)
            let sessionKey = try deriveSessionKey(
                ikm: sharedSecretBytes,
                salt: salt,
                info: "SKDevice",
                length: 32
            )
            print("SKDevice key generated")
            return sessionKey
        } catch {
            throw DecryptionError.skDeviceDerivationFailed
        }
    }

    public func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: theirPublicKey)
        print("sharedSecret computed successfully:\(sharedSecret)")
        _ = try deriveSKReader(sharedSecret: sharedSecret, sessionTranscriptBytes: salt)
        _ = try deriveSKDevice(sharedSecret: sharedSecret, sessionTranscriptBytes: salt)
        return Data()
    }
}
