import CryptoKit
import Foundation

public enum DecryptionError: LocalizedError, Equatable {
    case computeSharedSecretCurve(String)
    case computeSharedSecretMalformedKey(CryptoKitError)

    case eDeviceKeyIncompatibleCurve(String)
    case eDeviceKeyMalformed(CryptoKitError)

    case skReaderDerivationFailed
    case skDeviceDerivationFailed

    case payloadTooShort
    case authenticationError
    
    public var errorDescription: String? {
        switch self {
        case .computeSharedSecretCurve(let curve):
            return "Error computing shared secret (status code 10) due to EReaderKey.Pub with incompatible curve: \(curve)."
        case .computeSharedSecretMalformedKey(let error):
            return "Error computing shared secret (status code 10) due to malformed EReaderKey.Pub: \(error)."
        case .eDeviceKeyIncompatibleCurve(let curve):
            return "Error computing shared secret due to EDeviceKey.Pub with incompatible curve: \(curve)."
        case .eDeviceKeyMalformed(let error):
            return "Error computing shared secret due to malformed EDeviceKey.Pub: \(error)."
        case .skReaderDerivationFailed:
            return "SKReader derivation failure (status code 10 encryption error)"
        case .skDeviceDerivationFailed:
            return "SKDevice derivation failure (status code 10 encryption error)"
        case .payloadTooShort:
            return "Payload too short for AES-256-GCM (status code 20) - less than 16 bytes"
        case .authenticationError:
            return "session decryption error: authentication tag invalid (status code 20)"
        }
    }
}

public protocol Decryption {
    var publicKey: P256.KeyAgreement.PublicKey { get }
    var skDeviceKey: [UInt8]? { get }

    func decryptData(
        _ data: [UInt8],
        salt: [UInt8],
        messageCounter: Int,
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: EncryptionParameters
    ) throws -> Data

    func computeSharedSecret(using eDeviceKey: COSEKey) throws -> SharedSecret
}

final public class SessionDecryption: Decryption {
    public let privateKey: P256.KeyAgreement.PrivateKey
    public private(set) var skDeviceKey: [UInt8]?

    public var publicKey: P256.KeyAgreement.PublicKey {
        #if DEBUG
        print("public key is: \(privateKey.publicKey.pemRepresentation)")
        #endif
        return privateKey.publicKey
    }

    public convenience init() {
        self.init(privateKey: .init())
    }

    init(privateKey: P256.KeyAgreement.PrivateKey = .init()) {
        self.privateKey = privateKey
        #if DEBUG
        print("private key is: \(privateKey.pemRepresentation)")
        #endif
    }

    private func calculateSalt(from sessionTranscriptBytes: [UInt8]) -> [UInt8] {
        let digest = SHA256.hash(data: Data(sessionTranscriptBytes))
        return Array(digest)
    }

    public func computeSharedSecret(using eDeviceKey: COSEKey) throws -> SharedSecret {
        let eDevicePublicKey: P256.KeyAgreement.PublicKey
        do {
            eDevicePublicKey = try P256.KeyAgreement.PublicKey(coseKey: eDeviceKey)
        } catch COSEKeyError.unsupportedCurve(let curve) {
            let error = DecryptionError.eDeviceKeyIncompatibleCurve("\(curve)")
            print(error.localizedDescription)
            throw error
        } catch COSEKeyError.malformedKeyData(let cryptoKitError) {
            let error = DecryptionError.eDeviceKeyMalformed(cryptoKitError)
            print(error.localizedDescription)
            throw error
        }
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: eDevicePublicKey)
        print("Shared secret (ZAB) computed successfully")
        return sharedSecret
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
        messageCounter: Int,
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: theirPublicKey)
        print("sharedSecret computed successfully: \(sharedSecret)")
        let skReader = try deriveSKReader(sharedSecret: sharedSecret, sessionTranscriptBytes: salt)
        skDeviceKey = try deriveSKDevice(sharedSecret: sharedSecret, sessionTranscriptBytes: salt)

        let symmetricKey = SymmetricKey(data: Data(skReader))

        // check data is at least 16 bytes
        guard data.count >= 16 else {
            print(DecryptionError.payloadTooShort.localizedDescription)
            throw DecryptionError.payloadTooShort
        }
        
        // get the pieces for decryption
        let iv = constructIV(messageCounter: messageCounter, by: parameters)
        let nonce = try AES.GCM.Nonce(data: iv)
        let cipherText = data.dropLast(16) // Assuming the last 16 bytes are the tag
        let authenticationTag = data.suffix(16)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: cipherText,
            tag: authenticationTag
        )
        let decryptedData: Data
        do {
            decryptedData = try AES.GCM.open(
                sealedBox,
                using: symmetricKey
            )
            print("Payload was successfully decrypted")
            
            return decryptedData
        } catch CryptoKitError.authenticationFailure {
            print(DecryptionError.authenticationError.localizedDescription)
            throw DecryptionError.authenticationError
        } catch {
            print("There was an issue decrypting the data: \(error)")
            throw error
        }
    }
    
    private func constructIV(messageCounter: Int, by parameters: any EncryptionParameters) -> Data {
        // verifier is always known as this
        let identifier: [UInt8] = [UInt8](parameters.identifier)
        
        // convert message counter to [uint32]
        let messageCounterArray = withUnsafeBytes(of: UInt32(messageCounter).bigEndian, Array.init)
        let iv = identifier + messageCounterArray
        return Data(iv)
    }
}
