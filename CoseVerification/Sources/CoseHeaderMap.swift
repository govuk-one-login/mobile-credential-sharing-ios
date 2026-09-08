import Foundation
import SwiftCBOR

// MARK: - COSE Header Label

/// A COSE header label, which may be an integer or a text string per RFC 9052 §3.1.
enum CoseLabel: Hashable, Sendable {
    case int(Int64)
    case text(String)

    /// Well-known COSE header algorithm label (1).
    static let algorithmLabel = CoseLabel.int(1)

    /// RFC 9360 `x5bag` header label (32): an unordered bag of certificates.
    /// CoseVerification ignores this parameter and never uses it as chain material.
    static let x5bagLabel = CoseLabel.int(32)

    /// RFC 9360 `x5chain` header label (33): an ordered, leaf-first X.509 certificate chain.
    static let x5chainLabel = CoseLabel.int(33)

    /// RFC 9360 `x5t` header label (34): a certificate thumbprint `[hashAlg, hashValue]`.
    static let x5tLabel = CoseLabel.int(34)
}

// MARK: - CBOR Value (lightweight internal representation)

/// A minimal representation of CBOR values found in COSE header maps.
/// Only the subset needed for header inspection is represented.
enum CborValue: Sendable {
    case int(Int64)
    case uint(UInt64)
    case bytes(Data)
    case text(String)
    case array([CborValue])
    case map([(CoseLabel, CborValue)])
    case bool(Bool)
    case null
    case undefined
}

extension CborValue: Equatable {
    static func == (lhs: CborValue, rhs: CborValue) -> Bool {
        switch (lhs, rhs) {
        case (.int(let a), .int(let b)):
            return a == b
        case (.uint(let a), .uint(let b)):
            return a == b
        case (.bytes(let a), .bytes(let b)):
            return a == b
        case (.text(let a), .text(let b)):
            return a == b
        case (.array(let a), .array(let b)):
            return a == b
        case (.map(let a), .map(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.bool(let a), .bool(let b)):
            return a == b
        case (.null, .null):
            return true
        case (.undefined, .undefined):
            return true
        default:
            return false
        }
    }
}

// MARK: - COSE Header Map

/// An internal representation of a COSE header map with unique labels.
/// Constructed from a decoded CBOR map after duplicate-label validation.
struct CoseHeaderMap: Sendable {
    let entries: [CoseLabel: CborValue]

    /// The set of labels present in this header map.
    var labels: Set<CoseLabel> { Set(entries.keys) }

    /// Looks up the value for a given label.
    subscript(label: CoseLabel) -> CborValue? {
        entries[label]
    }
}

// MARK: - CBOR -> CoseLabel / CborValue conversion

extension CoseLabel {
    /// Converts a SwiftCBOR key to a CoseLabel.
    /// Returns nil if the CBOR value is not a valid header label (integer or text string).
    init?(cbor: CBOR) {
        switch cbor {
        case .unsignedInt(let v):
            self = .int(Int64(v))
        case .negativeInt(let v):
            // SwiftCBOR encodes negative as ~n (i.e. the raw value is n where actual = -1 - n)
            let actual = -1 - Int64(v)
            self = .int(actual)
        case .utf8String(let s):
            self = .text(s)
        default:
            return nil
        }
    }
}

extension CborValue {
    /// Converts a SwiftCBOR value to a CborValue.
    init(cbor: CBOR) {
        switch cbor {
        case .unsignedInt(let v):
            self = .uint(v)
        case .negativeInt(let v):
            let actual = -1 - Int64(v)
            self = .int(actual)
        case .byteString(let bytes):
            self = .bytes(Data(bytes))
        case .utf8String(let s):
            self = .text(s)
        case .array(let items):
            self = .array(items.map { CborValue(cbor: $0) })
        case .map(let pairs):
            let converted: [(CoseLabel, CborValue)] = pairs.compactMap { key, value in
                guard let label = CoseLabel(cbor: key) else { return nil }
                return (label, CborValue(cbor: value))
            }
            self = .map(converted)
        case .boolean(let b):
            self = .bool(b)
        case .null:
            self = .null
        case .undefined:
            self = .undefined
        case .tagged(_, let inner):
            // Preserve tagged values as their inner content for header inspection
            self = CborValue(cbor: inner)
        default:
            self = .undefined
        }
    }
}
