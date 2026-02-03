import SwiftCBOR

public extension CBOREncodable {
    func encode(options: SwiftCBOR.CBOROptions) -> [UInt8] {
        toCBOR(options: options).encode()
    }
}

public extension CBOREncodable {
    func asDataItem(options: CBOROptions) -> CBOR {
        .tagged(.encodedCBORDataItem, .byteString(encode(options: options)))
    }
}
