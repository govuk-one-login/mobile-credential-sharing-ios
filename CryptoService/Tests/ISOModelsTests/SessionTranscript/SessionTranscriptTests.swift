import Foundation
@testable import CryptoService
import SwiftCBOR
import Testing

@Suite("SessionTranscript tests")
struct SessionTranscriptTests {
    @Test("Successfully encodes with QR")
    func sessionTranscriptCanBeEncodedToCBORwithQR() async throws {
        let deviceEngagementBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
        let eReaderKeyBytes: [UInt8] = [0x09, 0x0A, 0x0B, 0x0C]
        let sessionTranscript = SessionTranscript(
            deviceEngagementBytes: deviceEngagementBytes,
            eReaderKeyBytes: eReaderKeyBytes,
            handover: .qr
        )
        
        #expect(sessionTranscript.toCBOR(options: CBOROptions()) == [
            .tagged(.encodedCBORDataItem, .byteString(deviceEngagementBytes)),
            .tagged(.encodedCBORDataItem, .byteString(eReaderKeyBytes)),
            .null
        ])
    }
}
