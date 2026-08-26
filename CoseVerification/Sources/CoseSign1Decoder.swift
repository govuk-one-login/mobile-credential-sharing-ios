import Foundation
import SwiftCBOR

/// Decodes raw bytes into a validated `CoseSign1`.
///
/// Validates:
/// - The input is valid CBOR
/// - The top-level value is an untagged array of exactly 4 elements
/// - Element types match the COSE_Sign1 structure
/// - Header maps contain no duplicate labels
/// - No label appears in both header maps
/// - The protected header declares `alg = -7` (ES256)
///
/// This type is internal to the `CoseVerification` module.
enum CoseSign1Decoder {

    /// The COSE algorithm identifier for ES256 (ECDSA w/ SHA-256 on P-256).
    private static let es256AlgorithmValue: Int64 = -7

    /// Decodes raw COSE_Sign1 bytes into a validated internal representation.
    ///
    /// - Parameter data: Raw CBOR-encoded COSE_Sign1 bytes.
    /// - Returns: A validated `CoseSign1`.
    /// - Throws: `CoseVerificationFailure.malformedCoseSign1` on structural failure.
    /// - Throws: `CoseVerificationFailure.unsupportedAlgorithm` if the algorithm is not ES256.
    static func decode(_ data: Data) throws -> CoseSign1 {
        let rawBytes = [UInt8](data)
        let cbor = try decodeCbor(data)
        let elements = try extractArrayElements(cbor)
        let (protectedHeaderBytes, protectedHeader) = try decodeProtectedHeader(elements[0])
        let unprotectedHeaderRawBytes = try extractUnprotectedHeaderRawBytes(from: rawBytes)
        let unprotectedHeader = try decodeUnprotectedHeader(elements[1], rawMapBytes: unprotectedHeaderRawBytes)
        try validateNoSharedLabels(protected: protectedHeader, unprotected: unprotectedHeader)
        let payload = try decodePayload(elements[2])
        let signature = try decodeSignature(elements[3])
        try validateAlgorithm(protectedHeader: protectedHeader)

        return CoseSign1(
            protectedHeaderBytes: protectedHeaderBytes,
            protectedHeader: protectedHeader,
            unprotectedHeader: unprotectedHeader,
            payload: payload,
            signature: signature
        )
    }

    // MARK: - Private Helpers

    /// Decodes raw bytes into a CBOR value, rejecting invalid CBOR.
    private static func decodeCbor(_ data: Data) throws -> CBOR {
        guard let decoded = try? CBOR.decode([UInt8](data)) else {
            throw CoseVerificationFailure.malformedCoseSign1
        }
        return decoded
    }

    /// Extracts exactly 4 elements from an untagged CBOR array.
    private static func extractArrayElements(_ cbor: CBOR) throws -> [CBOR] {
        // Reject tagged values — COSE_Sign1 must be untagged per the ticket requirements
        if case .tagged = cbor {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        guard case .array(let elements) = cbor else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        guard elements.count == 4 else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        return elements
    }

    /// Decodes element 0: the protected header.
    /// Must be a byte string whose contents decode to a CBOR map with no duplicate labels.
    /// Returns both the preserved raw bytes and the decoded map.
    private static func decodeProtectedHeader(_ element: CBOR) throws -> (Data, CoseHeaderMap) {
        guard case .byteString(let bytes) = element else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        let rawBytes = Data(bytes)

        // An empty protected header (zero-length byte string) is a valid empty map
        if bytes.isEmpty {
            return (rawBytes, CoseHeaderMap(entries: [:]))
        }

        guard let innerCbor = try? CBOR.decode(bytes) else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        let headerMap = try decodeHeaderMap(innerCbor, rawMapBytes: bytes)
        return (rawBytes, headerMap)
    }

    /// Decodes element 1: the unprotected header.
    /// Must be a CBOR map with no duplicate labels.
    ///
    /// SwiftCBOR silently deduplicates map keys when decoding into a `[CBOR: CBOR]` dictionary,
    /// so we cannot detect duplicates from the decoded element alone. Instead, we accept the
    /// original raw bytes for the unprotected header (extracted before decoding) and compare the
    /// CBOR-declared pair count against the deduplicated dictionary count.
    private static func decodeUnprotectedHeader(_ element: CBOR, rawMapBytes: [UInt8]) throws -> CoseHeaderMap {
        guard case .map(let dictionary) = element else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        let declaredPairCount = try readMapPairCount(from: rawMapBytes)
        if declaredPairCount != dictionary.count {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        return try buildHeaderMap(from: dictionary)
    }

    /// Extracts the raw bytes of the unprotected header map (element 1) from the original
    /// COSE_Sign1 input bytes, before SwiftCBOR has parsed and deduplicated them.
    ///
    /// A COSE_Sign1 is encoded as: `84 <protected_bstr> <unprotected_map> <payload> <signature>`
    /// where `84` is the CBOR array header for exactly 4 elements.
    ///
    /// We skip past the array header (1 byte) and the protected header byte string to find
    /// the start of the unprotected header map in the original raw bytes.
    private static func extractUnprotectedHeaderRawBytes(from bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count > 1 else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Skip the 4-element array header. A 4-element array is always encoded as 0x84 (1 byte).
        var offset = 1

        // Skip the protected header byte string.
        //
        // CBOR encodes a byte string as: [initial byte] [optional length bytes] [content bytes]
        //
        // The initial byte's lower 5 bits ("additional info") tell us how the content length
        // is encoded:
        //   0–23:  the value IS the content length (no extra bytes)
        //   24:    the next 1 byte holds the content length
        //   25:    the next 2 bytes hold the content length (big-endian)
        let bstrInitialByte = bytes[offset]

        // Bitwise AND with 0x1F (binary: 00011111) masks off the top 3 bits (the major type),
        // leaving only the bottom 5 bits which encode the "additional info" — this tells us
        // how the byte string's content length is represented.
        let additionalInfo = bstrInitialByte & 0x1F

        let contentLength: Int
        let headerSize: Int

        switch additionalInfo {
        case 0...23:
            // Length fits in the initial byte itself — the additional info IS the length
            contentLength = Int(additionalInfo)
            headerSize = 1
        case 24:
            // Length is in the next 1 byte
            guard offset + 1 < bytes.count else { throw CoseVerificationFailure.malformedCoseSign1 }
            contentLength = Int(bytes[offset + 1])
            headerSize = 2
        case 25:
            // Length is in the next 2 bytes, stored big-endian (most significant byte first).
            // `<< 8` shifts the first byte left by 8 bits to put it in the upper position,
            // then `|` combines it with the second byte in the lower position,
            // reconstructing the original 16-bit integer.
            // e.g. bytes [0x01, 0x00] → (0x01 << 8) | 0x00 = 256
            guard offset + 2 < bytes.count else { throw CoseVerificationFailure.malformedCoseSign1 }
            contentLength = Int(UInt16(bytes[offset + 1]) << 8 | UInt16(bytes[offset + 2]))
            headerSize = 3
        default:
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Move past the entire protected header byte string (its CBOR header + its content)
        offset += headerSize + contentLength

        guard offset < bytes.count else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Everything from here starts with the unprotected header map.
        // We only need enough bytes for readMapPairCount (the initial byte + up to 4 length bytes),
        // but returning the rest of the buffer is fine and avoids computing the map's total length.
        return Array(bytes[offset...])
    }

    /// Decodes element 2: the payload.
    /// Must be a byte string (attached) or null (detached).
    private static func decodePayload(_ element: CBOR) throws -> Data? {
        switch element {
        case .byteString(let bytes):
            return Data(bytes)
        case .null:
            return nil
        default:
            throw CoseVerificationFailure.malformedCoseSign1
        }
    }

    /// Decodes element 3: the signature.
    /// Must be a byte string.
    private static func decodeSignature(_ element: CBOR) throws -> Data {
        guard case .byteString(let bytes) = element else {
            throw CoseVerificationFailure.malformedCoseSign1
        }
        return Data(bytes)
    }

    /// Decodes a CBOR value that must be a map, validating no duplicate labels
    /// using the raw bytes to count the declared pair count.
    private static func decodeHeaderMap(_ cbor: CBOR, rawMapBytes: [UInt8]) throws -> CoseHeaderMap {
        guard case .map(let dictionary) = cbor else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Detect duplicates: compare CBOR-declared pair count with dictionary count
        let declaredPairCount = try readMapPairCount(from: rawMapBytes)
        if declaredPairCount != dictionary.count {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        return try buildHeaderMap(from: dictionary)
    }

    /// Builds a CoseHeaderMap from a SwiftCBOR dictionary.
    /// All labels must be valid COSE labels (integer or text string).
    private static func buildHeaderMap(from dictionary: [CBOR: CBOR]) throws -> CoseHeaderMap {
        var entries: [CoseLabel: CborValue] = [:]
        entries.reserveCapacity(dictionary.count)

        for (key, value) in dictionary {
            guard let label = CoseLabel(cbor: key) else {
                throw CoseVerificationFailure.malformedCoseSign1
            }
            entries[label] = CborValue(cbor: value)
        }

        return CoseHeaderMap(entries: entries)
    }

    /// Validates that no label appears in both the protected and unprotected headers.
    private static func validateNoSharedLabels(
        protected protectedHeader: CoseHeaderMap,
        unprotected unprotectedHeader: CoseHeaderMap
    ) throws {
        let sharedLabels = protectedHeader.labels.intersection(unprotectedHeader.labels)
        if !sharedLabels.isEmpty {
            throw CoseVerificationFailure.malformedCoseSign1
        }
    }

    /// Validates that the protected header contains `alg = -7` (ES256).
    private static func validateAlgorithm(protectedHeader: CoseHeaderMap) throws {
        guard let algValue = protectedHeader[.algorithm] else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        // The algorithm value must be the integer -7 (ES256)
        switch algValue {
        case .int(let value) where value == es256AlgorithmValue:
            return
        default:
            throw CoseVerificationFailure.unsupportedAlgorithm
        }
    }

    // MARK: - CBOR Map Pair Count Reader

    /// Reads the declared number of pairs from a CBOR-encoded map's header bytes.
    /// This allows detecting duplicates that SwiftCBOR's dictionary silently discards.
    ///
    /// CBOR map encoding (RFC 8949 §3.1):
    /// - Major type 5 (bits 7-5 = 0b101)
    /// - Additional info (bits 4-0) encodes the pair count
    private static func readMapPairCount(from bytes: [UInt8]) throws -> Int {
        guard !bytes.isEmpty else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        let initialByte = bytes[0]
        let majorType = initialByte >> 5
        let additionalInfo = initialByte & 0x1F

        // Must be major type 5 (map)
        guard majorType == 5 else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        switch additionalInfo {
        case 0...23:
            return Int(additionalInfo)
        case 24:
            guard bytes.count >= 2 else {
                throw CoseVerificationFailure.malformedCoseSign1
            }
            return Int(bytes[1])
        case 25:
            guard bytes.count >= 3 else {
                throw CoseVerificationFailure.malformedCoseSign1
            }
            return Int(UInt16(bytes[1]) << 8 | UInt16(bytes[2]))
        case 26:
            guard bytes.count >= 5 else {
                throw CoseVerificationFailure.malformedCoseSign1
            }
            let value = UInt32(bytes[1]) << 24 | UInt32(bytes[2]) << 16 |
                        UInt32(bytes[3]) << 8 | UInt32(bytes[4])
            return Int(value)
        case 31:
            // Indefinite-length map - not valid in deterministic CBOR,
            // but we can't easily count pairs without full parsing.
            // Reject as malformed for COSE purposes (RFC 9052 requires deterministic encoding).
            throw CoseVerificationFailure.malformedCoseSign1
        default:
            throw CoseVerificationFailure.malformedCoseSign1
        }
    }
}
