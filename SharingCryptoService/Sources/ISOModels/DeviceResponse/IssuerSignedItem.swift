import Foundation
import SwiftCBOR

public struct IssuerSignedItem: Equatable, Hashable, Sendable {
    let digestID: UInt
    let random: [UInt8]
    public let elementIdentifier: String
    public let elementValue: CBOR
    /// When set, toCBOR returns this verbatim to preserve MSO hash integrity.
    private let originalCBOR: CBOR?
    
    public init(digestID: UInt, random: [UInt8], elementIdentifier: String, elementValue: CBOR) {
        self.digestID = digestID
        self.random = random
        self.elementIdentifier = elementIdentifier
        self.elementValue = elementValue
        self.originalCBOR = nil
    }

    /// Constructs from original Tag 24 CBOR, preserving raw bytes for MSO validity
    /// and decoding the element fields for consumer access.
    public init(rawCBOR: CBOR) throws {
        self.originalCBOR = rawCBOR

        guard case let .tagged(_, .byteString(bytes)) = rawCBOR,
              let decoded = try? CBOR.decode(bytes),
              case let .map(map) = decoded else {
            throw DeviceResponseError.cborDecodingError
        }

        if case let .unsignedInt(id) = map[.utf8String("digestID")] {
            self.digestID = UInt(id)
        } else {
            self.digestID = 0
        }
        if case let .byteString(randomBytes) = map[.utf8String("random")] {
            self.random = randomBytes
        } else {
            self.random = []
        }
        if case let .utf8String(identifier) = map[.utf8String("elementIdentifier")] {
            self.elementIdentifier = identifier
        } else {
            self.elementIdentifier = ""
        }
        self.elementValue = map[.utf8String("elementValue")] ?? .null
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
