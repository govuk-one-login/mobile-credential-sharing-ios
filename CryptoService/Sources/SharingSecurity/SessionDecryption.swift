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
        
        // mocking a symmtetric key from iso spec here, will remove once code for generating key is done
        let keyString = "58d277d8719e62a1561d248f403f477e9e6c37bf5d5fc5126f8f4c727c22dfc9"
        let skreader = Data(hex: keyString)
        let symmetricKey = SymmetricKey(data: skreader ?? Data())
        
        // get the pieces for decryption
        let iv = constructIV(messageCounter: 1)
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
            return decryptedData
        } catch {
            print("Decryption failed: \(error)")
        }
        return Data()
    }
    
    private func constructIV(messageCounter: Int) -> Data {
        // verifier is always known as this
        let identifier: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        
        // convert message counter to [uint32]
        let messageCounterArray = withUnsafeBytes(of: Int32(messageCounter).bigEndian, Array.init)
        let iv = identifier + messageCounterArray
        return Data(iv)
    }
}

// get rid of this once symmetrical keys aren't being mocked in from iso spec
extension Data {
    init?(hex: String) {
        let hex = hex.count % 2 == 0 ? hex : "0" + hex
        var data = Data(capacity: hex.count / 2)

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard nextIndex <= hex.endIndex,
                  let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
