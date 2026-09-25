import Foundation
import SwiftCBOR

/// One `ItemsRequest` preserved as its complete `#6.24(bstr .cbor ItemsRequest)`
/// encoding. The same bytes are signed and transmitted, so they are never
/// re-encoded. Owns its `Data`.
public struct ItemsRequestBytes: Sendable, Equatable {

    public let bytes: Data

    /// Wraps already-encoded Tag 24 `ItemsRequest` bytes as this value.
    /// Validates the outer Tag 24 byte-string shape only; the embedded item is
    /// opaque (its single-item validity is guaranteed by the producer).
    ///
    /// - Throws: `.invalidTag24` if not a Tag 24 byte-string wrapper.
    public init(from bytes: Data) throws {
        try Self.validateTag24Shape(bytes)
        self.bytes = Data(bytes)
    }

    /// Validates the outer `#6.24(bstr ...)` shape only. EF2 inbound decoding
    /// must copy each item's exact original bytes, not rely on this check.
    static func validateTag24Shape(_ data: Data) throws {
        guard
            let item = try? CBOR.decode([UInt8](data)),
            case .tagged(.encodedCBORDataItem, .byteString) = item
        else {
            throw ExchangeFormatError.invalidTag24
        }
    }
}
