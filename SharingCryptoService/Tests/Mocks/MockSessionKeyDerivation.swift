import Foundation
import SharingCryptoService

class MockSessionKeyDerivation: SessionKeyDerivation {
    var skReaderKeyToReturn: [UInt8] = [UInt8](repeating: 0xAA, count: 32)
    var skDeviceKeyToReturn: [UInt8] = [UInt8](repeating: 0xBB, count: 32)
    var deriveSKReaderShouldThrow = false
    var deriveSKDeviceShouldThrow = false

    func deriveSKReader(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) throws -> [UInt8] {
        if deriveSKReaderShouldThrow {
            throw DecryptionError.skReaderDerivationFailed
        }
        return skReaderKeyToReturn
    }

    func deriveSKDevice(
        sharedSecret: some ContiguousBytes,
        sessionTranscriptBytes: [UInt8]
    ) throws -> [UInt8] {
        if deriveSKDeviceShouldThrow {
            throw DecryptionError.skDeviceDerivationFailed
        }
        return skDeviceKeyToReturn
    }
}
