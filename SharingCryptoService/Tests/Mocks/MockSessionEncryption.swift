import CryptoKit
import Foundation
import SharingCryptoService

class MockSessionEncryption: Encryption {
    func encryptData(
        _ data: Data,
        using key: [UInt8],
        messageCounter: inout Int,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        messageCounter += 1
        return Data()
    }
}
