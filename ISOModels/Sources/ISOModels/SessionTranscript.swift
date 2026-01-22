import SwiftCBOR

public struct SessionTranscript {
    let deviceEngagementBytes: [UInt8]
    let eReaderKeyBytes: [UInt8]
    let handover: Handover
    
    public init(
        deviceEngagementBytes: [UInt8],
        eReaderKeyBytes: [UInt8],
        handover: Handover
    ) {
        self.deviceEngagementBytes = deviceEngagementBytes
        self.eReaderKeyBytes = eReaderKeyBytes
        self.handover = handover
    }
}

extension SessionTranscript: CBOREncodable {
    public func toCBOR(options: CBOROptions) -> CBOR {
        return [
            .tagged(.encodedCBORDataItem, .byteString(deviceEngagementBytes)),
            .tagged(.encodedCBORDataItem, .byteString(eReaderKeyBytes)),
            .null
        ]
    }
}

public enum Handover {
    case qr
}
