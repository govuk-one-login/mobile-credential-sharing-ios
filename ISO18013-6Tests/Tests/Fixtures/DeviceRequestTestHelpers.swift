import Foundation
import SwiftCBOR
import Testing

// MARK: - CBOR Test Vector Loading

/// Loads a CBOR hex test vector from a resource file relative to the test bundle.
/// - Parameter filename: The resource filename (without path prefix) in Tests/Resources/
/// - Returns: The raw Data decoded from hex
func loadCborHex(_ filename: String) throws -> Data {
    let thisFile = URL(fileURLWithPath: #filePath)
    let resourcesDir = thisFile
        .deletingLastPathComponent() // Fixtures/
        .deletingLastPathComponent() // Tests/
        .appendingPathComponent("Resources")
        .appendingPathComponent(filename)

    let hexString = try String(contentsOf: resourcesDir, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return try #require(dataFromHex(hexString))
}

/// Converts a hex-encoded string to Data.
func dataFromHex(_ hex: String) -> Data? {
    let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleaned.count.isMultiple(of: 2) else { return nil }
    var data = Data(capacity: cleaned.count / 2)
    var index = cleaned.startIndex
    while index < cleaned.endIndex {
        let nextIndex = cleaned.index(index, offsetBy: 2)
        guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else { return nil }
        data.append(byte)
        index = nextIndex
    }
    return data
}

// MARK: - Common CBOR Validation (Appendix 1, 1.1)

/// Performs Common_CBOR validation checks on raw CBOR bytes:
/// 1. Well-formedness: bytes decode without error
/// 2. Canonical encoding: map keys are in deterministic order (shorter encoded keys first, then lexicographic)
/// 3. Unique keys: no duplicate keys in any map
///
/// Uses a byte-level parser to verify canonical key ordering, since SwiftCBOR's decoded
/// dictionary does not preserve wire order.
///
/// - Parameter data: The raw CBOR bytes to validate
/// - Returns: The decoded CBOR value
@discardableResult
func validateCommonCBOR(_ data: Data) throws -> CBOR {
    let bytes = [UInt8](data)

    // 1. Well-formed: decodes without error
    let decoded = try #require(try CBOR.decode(bytes), "CBOR must be well-formed and decodable")

    // 2 & 3. Verify canonical key ordering and uniqueness on the raw bytes
    try validateCanonicalOrdering(bytes: bytes, offset: 0)

    return decoded
}

// MARK: - Byte-Level Canonical CBOR Validation

/// Recursively validates canonical key ordering and uniqueness in all maps within the CBOR structure,
/// operating directly on the raw byte representation.
///
/// Canonical CBOR (RFC 7049 §3.9 / deterministic encoding):
/// - Map keys sorted by length of encoded key (shorter first)
/// - If same length, sorted by lexicographic byte comparison
@discardableResult
// swiftlint:disable:next function_body_length
private func validateCanonicalOrdering(bytes: [UInt8], offset: Int) throws -> Int {
    guard offset < bytes.count else {
        Issue.record("Unexpected end of CBOR data at offset \(offset)")
        return offset
    }

    let firstByte = bytes[offset]
    let majorType = firstByte >> 5
    let additionalInfo = firstByte & 0x1F

    switch majorType {
    case 0, 1: // unsigned/negative int
        return offset + encodedIntHeaderLength(additionalInfo)

    case 2, 3: // byte string / text string
        let (length, headerSize) = try decodeLength(bytes: bytes, offset: offset, additionalInfo: additionalInfo)
        return offset + headerSize + Int(length)

    case 4: // array
        let (count, headerSize) = try decodeLength(bytes: bytes, offset: offset, additionalInfo: additionalInfo)
        var pos = offset + headerSize
        for _ in 0..<Int(count) {
            pos = try validateCanonicalOrdering(bytes: bytes, offset: pos)
        }
        return pos

    case 5: // map
        let (count, headerSize) = try decodeLength(bytes: bytes, offset: offset, additionalInfo: additionalInfo)
        var pos = offset + headerSize
        var previousKeyBytes: [UInt8]?

        for _ in 0..<Int(count) {
            // Record the key start and end to extract raw key bytes
            let keyStart = pos
            pos = try validateCanonicalOrdering(bytes: bytes, offset: pos)
            let keyEnd = pos
            let currentKeyBytes = Array(bytes[keyStart..<keyEnd])

            // Check canonical ordering against previous key
            if let prevKey = previousKeyBytes {
                // Uniqueness check
                #expect(
                    prevKey != currentKeyBytes,
                    "Duplicate map key detected at offset \(keyStart)"
                )
                // Canonical ordering: shorter keys first, then lexicographic
                let isOrdered: Bool
                if prevKey.count != currentKeyBytes.count {
                    isOrdered = prevKey.count < currentKeyBytes.count
                } else {
                    isOrdered = prevKey.lexicographicallyPrecedes(currentKeyBytes)
                }
                #expect(
                    isOrdered,
                    "Map keys not in canonical order at offset \(keyStart)"
                )
            }
            previousKeyBytes = currentKeyBytes

            // Recurse into value
            pos = try validateCanonicalOrdering(bytes: bytes, offset: pos)
        }
        return pos

    case 6: // tagged
        let (_, headerSize) = try decodeLength(bytes: bytes, offset: offset, additionalInfo: additionalInfo)
        return try validateCanonicalOrdering(bytes: bytes, offset: offset + headerSize)

    case 7: // simple/float
        return offset + encodedIntHeaderLength(additionalInfo)

    default:
        Issue.record("Unknown CBOR major type \(majorType) at offset \(offset)")
        return offset + 1
    }
}

/// Returns the number of bytes consumed by an integer header given the additional info value.
private func encodedIntHeaderLength(_ additionalInfo: UInt8) -> Int {
    switch additionalInfo {
    case 0...23: return 1
    case 24: return 2
    case 25: return 3
    case 26: return 5
    case 27: return 9
    default: return 1
    }
}

/// Decodes the length/count from CBOR additional info and following bytes.
/// Returns (value, total header bytes consumed including the initial byte).
private func decodeLength(bytes: [UInt8], offset: Int, additionalInfo: UInt8) throws -> (UInt64, Int) {
    switch additionalInfo {
    case 0...23:
        return (UInt64(additionalInfo), 1)
    case 24:
        guard offset + 1 < bytes.count else {
            Issue.record("Unexpected end of data reading 1-byte length at offset \(offset)")
            return (0, 2)
        }
        return (UInt64(bytes[offset + 1]), 2)
    case 25:
        guard offset + 2 < bytes.count else {
            Issue.record("Unexpected end of data reading 2-byte length at offset \(offset)")
            return (0, 3)
        }
        let val = UInt64(bytes[offset + 1]) << 8 | UInt64(bytes[offset + 2])
        return (val, 3)
    case 26:
        guard offset + 4 < bytes.count else {
            Issue.record("Unexpected end of data reading 4-byte length at offset \(offset)")
            return (0, 5)
        }
        let val = UInt64(bytes[offset + 1]) << 24 | UInt64(bytes[offset + 2]) << 16 |
                  UInt64(bytes[offset + 3]) << 8 | UInt64(bytes[offset + 4])
        return (val, 5)
    case 27:
        guard offset + 8 < bytes.count else {
            Issue.record("Unexpected end of data reading 8-byte length at offset \(offset)")
            return (0, 9)
        }
        var val: UInt64 = 0
        for i in 1...8 {
            val = val << 8 | UInt64(bytes[offset + i])
        }
        return (val, 9)
    default:
        Issue.record("Invalid additional info \(additionalInfo) at offset \(offset)")
        return (0, 1)
    }
}
