import CryptoKit
import Foundation

public enum EncryptionError: LocalizedError, Equatable {
    case encryptionFailed

    public var errorDescription: String {
        switch self {
        case .encryptionFailed:
            return "AES-256-GCM encryption failed (status code 10)"
        }
    }
}

public protocol Encryption {
    func encryptData(
        _ data: Data,
        using key: [UInt8],
        messageCounter: inout Int,
        by parameters: EncryptionParameters
    ) throws -> Data
}

public final class SessionEncryption: Encryption {
    public init() {}

    public func encryptData(
        _ data: Data,
        using key: [UInt8],
        messageCounter: inout Int,
        by parameters: EncryptionParameters
    ) throws -> Data {
        let symmetricKey = SymmetricKey(data: Data(key))
        let iv = constructIV(messageCounter: messageCounter, by: parameters)
        let nonce = try AES.GCM.Nonce(data: iv)

        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)
            messageCounter += 1
            return sealedBox.ciphertext + sealedBox.tag
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }

    private func constructIV(messageCounter: Int, by parameters: EncryptionParameters) -> Data {
        let identifier = [UInt8](parameters.identifier)
        let counterBytes = withUnsafeBytes(of: Int32(messageCounter).bigEndian, Array.init)
        return Data(identifier + counterBytes)
    }
}
