import Foundation
import SwiftCBOR

public struct IssuerSigned: Equatable, Hashable, Sendable {
    public let nameSpaces: [String: [IssuerSignedItem]]
    let issuerAuth: [UInt8]
    
    public init(nameSpaces: [String: [IssuerSignedItem]], issuerAuth: [UInt8]) {
        self.nameSpaces = nameSpaces
        self.issuerAuth = issuerAuth
    }

    /// Decodes `IssuerSigned` from a CBOR value.
    init(cbor: CBOR) throws {
        guard case let .map(issuerSignedMap) = cbor,
              case let .map(nameSpacesMap) = issuerSignedMap[.nameSpaces]
        else {
            throw DeviceResponseError.cborDecodingError
        }

        // Extract issuerAuth as raw bytes
        guard let issuerAuthCBOR = issuerSignedMap[.issuerAuth] else {
            throw DeviceResponseError.cborDecodingError
        }
        self.issuerAuth = issuerAuthCBOR.encode()

        // Parse each namespace and its items
        var parsedNameSpaces: [String: [IssuerSignedItem]] = [:]
        for (nameSpaceKey, itemsValue) in nameSpacesMap {
            guard case let .utf8String(nameSpace) = nameSpaceKey,
                  case let .array(items) = itemsValue else {
                throw DeviceResponseError.cborDecodingError
            }

            let parsedItems: [IssuerSignedItem] = try items.map { item in
                // Each item should be Tag 24 (#6.24) wrapping a byte string
                // Validate Tag 24 contains a valid inner byte string
                guard case .tagged(.encodedCBORDataItem, .byteString) = item else {
                    throw DeviceResponseError.cborDecodingError
                }
                // Preserve the entire Tag 24 structure unmodified
                return try IssuerSignedItem(rawCBOR: item)
            }

            parsedNameSpaces[nameSpace] = parsedItems
        }

        self.nameSpaces = parsedNameSpaces
    }
}

extension IssuerSigned: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        guard let decodedIssuerAuth = try? CBOR.decode(issuerAuth) else {
            return .break
        }
        return .map([
            .nameSpaces: .map(nameSpaces.mapKeys { .utf8String($0) }.mapValues { items in
                .array(items.map { $0.toCBOR(options: options) })
            }),
            .issuerAuth: decodedIssuerAuth
        ])
    }
}

fileprivate extension CBOR {
    static var nameSpaces: CBOR { "nameSpaces" }
    static var issuerAuth: CBOR { "issuerAuth" }
}

fileprivate extension Dictionary {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        [T: Value](uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
