import CryptoKit
import Foundation
import SharingLogging

public enum DecryptionError: LocalizedError, Equatable {
    case payloadTooShort
    case authenticationError
    
    public var errorDescription: String? {
        switch self {
        case .payloadTooShort:
            return "Payload too short for AES-256-GCM (status code 20) - less than 16 bytes"
        case .authenticationError:
            return "session decryption error: authentication tag invalid (status code 20)"
        }
    }
}

public protocol Decryption {
    func deriveSKReader(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) -> [UInt8]

    func deriveSKDevice(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) -> [UInt8]

    func decryptData(
        _ data: [UInt8],
        using key: [UInt8],
        messageCounter: Int,
        by parameters: EncryptionParameters
    ) throws -> Data
}

final public class SessionDecryption: Decryption {
    public init() {
        // Empty init required to make class public facing
    }

    private func calculateSalt(
        from sessionTranscriptBytes: [UInt8]
    ) -> [UInt8] {
        let digest = SHA256.hash(data: Data(sessionTranscriptBytes))
        return Array(digest)
    }

    private func extractSharedSecretBytes(
        from sharedSecret: some ContiguousBytes
    ) -> [UInt8] {
        sharedSecret.withUnsafeBytes { Array($0) }
    }

    private func deriveSessionKey(
        ikm: [UInt8],
        salt: [UInt8],
        info: String,
        length: Int
    ) -> [UInt8] {
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
    ) -> [UInt8] {
        let salt = calculateSalt(from: sessionTranscriptBytes)
        let sharedSecretBytes = extractSharedSecretBytes(from: sharedSecret)
        let sessionKey = deriveSessionKey(
            ikm: sharedSecretBytes,
            salt: salt,
            info: "SKReader",
            length: 32
        )
        Logger.log("SKReader key generated")
        return sessionKey
    }

    public func deriveSKDevice(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) -> [UInt8] {
        let salt = calculateSalt(from: sessionTranscriptBytes)
        let sharedSecretBytes = extractSharedSecretBytes(from: sharedSecret)
        let sessionKey = deriveSessionKey(
            ikm: sharedSecretBytes,
            salt: salt,
            info: "SKDevice",
            length: 32
        )
        Logger.log("SKDevice key generated")
        return sessionKey
    }

    public func decryptData(
        _ data: [UInt8],
        using key: [UInt8],
        messageCounter: Int,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        let symmetricKey = SymmetricKey(data: Data(key))

        // check data is at least 16 bytes
        guard data.count >= 16 else {
            Logger.log(DecryptionError.payloadTooShort.localizedDescription, level: .error)
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
            Logger.log("Payload was successfully decrypted")
            
            return decryptedData
        } catch CryptoKitError.authenticationFailure {
            Logger.log(DecryptionError.authenticationError.localizedDescription, level: .error)
            throw DecryptionError.authenticationError
        } catch {
            Logger.log("There was an issue decrypting the data: \(error)", level: .error)
            throw error
        }
    }
    
    private func constructIV(
        messageCounter: Int,
        by parameters: any EncryptionParameters
    ) -> Data {
        // verifier is always known as this
        let identifier: [UInt8] = [UInt8](parameters.identifier)
        
        // convert message counter to [uint32]
        let messageCounterArray = withUnsafeBytes(of: UInt32(messageCounter).bigEndian, Array.init)
        let iv = identifier + messageCounterArray
        return Data(iv)
    }
}
