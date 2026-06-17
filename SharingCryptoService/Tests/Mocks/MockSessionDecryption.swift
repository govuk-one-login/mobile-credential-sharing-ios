import CryptoKit
import Foundation
import SharingCryptoService

class MockSessionDecryption: Decryption {
    var skDeviceKey: [UInt8]?
    var decryptedDataToReturn = Data()
    var skReaderKeyToReturn: [UInt8] = [UInt8](repeating: 0xAA, count: 32)
    var skDeviceKeyToReturn: [UInt8] = [UInt8](repeating: 0xBB, count: 32)

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
        salt: [UInt8],
        messageCounter: Int,
        encryptedWith theirPublicKey: P256.KeyAgreement.PublicKey,
        using privateKey: P256.KeyAgreement.PrivateKey,
        by parameters: any EncryptionParameters
    ) throws -> Data {
        skDeviceKey = [0, 1]
        return decryptedDataToReturn
    }
}
