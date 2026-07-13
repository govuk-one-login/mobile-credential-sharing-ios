import CryptoKit
import Foundation
import SharingCryptoService

class MockSessionDecryption: Decryption {
    var decryptedDataToReturn = Data()
    var skReaderKeyToReturn: [UInt8] = [UInt8](repeating: 0xAA, count: 32)
    var skDeviceKeyToReturn: [UInt8] = [UInt8](repeating: 0xBB, count: 32)
    var decryptDataShouldThrow: Error?

    func deriveSKReader(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) -> [UInt8] {
        return skReaderKeyToReturn
    }

    func deriveSKDevice(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) -> [UInt8] {
        return skDeviceKeyToReturn
    }

    func decryptData(
        _ data: [UInt8],
        using key: [UInt8],
        messageCounter: Int,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        if let error = decryptDataShouldThrow {
            throw error
        }
        return decryptedDataToReturn
    }
}
