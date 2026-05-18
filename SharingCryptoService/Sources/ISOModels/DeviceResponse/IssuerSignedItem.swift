import Foundation
import SwiftCBOR

public struct IssuerSignedItem: Equatable, Hashable, Sendable {
    let digestID: UInt
    let random: [UInt8]
    let elementIdentifier: String
    let elementValue: CBOR
    /// When set, toCBOR returns this verbatim to preserve MSO hash integrity.
    private let originalCBOR: CBOR?
    
    public init(digestID: UInt, random: [UInt8], elementIdentifier: String, elementValue: CBOR) {
        self.digestID = digestID
        self.random = random
        self.elementIdentifier = elementIdentifier
        self.elementValue = elementValue
        self.originalCBOR = nil
    }

    /// Constructs from original Tag 24 CBOR, preserving bytes for MSO validity.
    public init(rawCBOR: CBOR) {
        self.originalCBOR = rawCBOR
        // These fields are unused when originalCBOR is set, but required by the struct
        self.digestID = 0
        self.random = []
        self.elementIdentifier = ""
        self.elementValue = .null
    }
}

extension IssuerSignedItem: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        if let originalCBOR {
            return originalCBOR
        }
        return .tagged(.encodedCBORDataItem, .byteString(
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
