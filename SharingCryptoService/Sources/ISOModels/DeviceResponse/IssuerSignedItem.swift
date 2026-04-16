import Foundation
import SwiftCBOR

public struct IssuerSignedItem: Equatable, Hashable, Sendable {
    let digestID: UInt
    let random: [UInt8]
    let elementIdentifier: String
    let elementValue: CBOR
    
    public init(digestID: UInt, random: [UInt8], elementIdentifier: String, elementValue: CBOR) {
        self.digestID = digestID
        self.random = random
        self.elementIdentifier = elementIdentifier
        self.elementValue = elementValue
    }
}

extension IssuerSignedItem: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        .tagged(.encodedCBORDataItem, .byteString(
            CBOR.map([
                .digestID: .unsignedInt(UInt64(digestID)),
                .random: .byteString(random),
                .elementIdentifier: .utf8String(elementIdentifier),
                .elementValue: elementValue
            ]).encode()
        ))
    }
}

fileprivate extension CBOR {
    static var digestID: CBOR { "digestID" }
    static var random: CBOR { "random" }
    static var elementIdentifier: CBOR { "elementIdentifier" }
    static var elementValue: CBOR { "elementValue" }
}

extension CBOR: @unchecked @retroactive Sendable {}
