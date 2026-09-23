import Foundation

public enum ExchangeFormatError: Error, Equatable, Sendable {
    /// An owned request or response map lacks a required field.
    case missingRequiredField
    /// An owned field has an invalid CBOR type or collection shape.
    case malformedStructure
    /// An owned map repeats a key.
    case duplicateKey
    /// A required Tag 24 value or embedded item is invalid.
    case invalidTag24
    /// A decoder cannot retain a required signed or digested source range.
    case sourceRangeUnavailable
    /// Bytes remain after one complete top-level or embedded item.
    case trailingData
    /// Deterministic output construction cannot complete.
    case encodingFailure
}
