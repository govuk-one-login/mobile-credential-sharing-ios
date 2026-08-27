import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// MARK: - DeviceRequest Generation

/// Builds a valid DeviceRequest using the verifier's own ISO models and encodes it to CBOR bytes.
///
/// This drives the same production types (`DeviceRequest`, `DocRequest`, `AttributeGroup`) and the
/// same `CBOREncodable` path that `CryptoService.encryptDeviceRequest` uses on the wire, rather than
/// relying on a static hex fixture. The resulting bytes are what the verifier would actually transmit.
///
/// Structure: DeviceRequest { version: "1.0", docRequests: [DocRequest { itemsRequest }] }
/// with an mDL DocRequest requesting `given_name` (intentToRetain: false) and
/// `family_name` (intentToRetain: true) from the standard namespace.
///
/// - Returns: The CBOR-encoded DeviceRequest bytes produced by the verifier models.
func makeValidDeviceRequestData() throws -> Data {
    let group = try #require(
        AttributeGroup(
            docType: .mdl,
            mdlAttributes: [
                .init(attribute: .givenName, intentToRetain: false),
                .init(attribute: .familyName, intentToRetain: true)
            ]
        ),
        "AttributeGroup must be constructable with at least one attribute"
    )
    let deviceRequest = DeviceRequest(docRequests: [DocRequest(with: group)])
    return Data(deviceRequest.toCBOR().encode())
}

/// Builds a DeviceRequest whose DocRequest additionally carries a `readerAuth` COSE_Sign1 structure,
/// then encodes it to CBOR bytes.
///
/// The verifier's `DocRequest` model does not populate `readerAuth` (MVP), and when set it encodes as a
/// bstr rather than the COSE_Sign1 array required by ISO 18013-5 §8.3.2.1.2.1. To exercise the
/// conformance checks for the optional `readerAuth` element, we generate the base DocRequest from the
/// verifier models and then splice in a COSE_Sign1 array (`[protected, {}, null, signature]`) at the
/// CBOR level, preserving the model-generated `itemsRequest`.
///
/// - Returns: The CBOR-encoded DeviceRequest bytes with a readerAuth-bearing DocRequest.
func makeDeviceRequestDataWithReaderAuth() throws -> Data {
    let group = try #require(
        AttributeGroup(
            docType: .mdl,
            mdlAttributes: [
                .init(attribute: .givenName, intentToRetain: false),
                .init(attribute: .familyName, intentToRetain: true)
            ]
        ),
        "AttributeGroup must be constructable with at least one attribute"
    )
    let docRequest = DocRequest(with: group)

    // Reuse the model-generated itemsRequest (Tag(24, bstr(ItemsRequest_CBOR))) verbatim.
    let itemsRequestDataItem = docRequest.itemsRequest.asDataItem(options: CBOROptions())

    // COSE_Sign1 = [ protected: bstr, unprotected: map, payload: null, signature: bstr ]
    // A dummy but structurally valid reader authentication value.
    let readerAuth: CBOR = .array([
        .byteString([]),           // protected header (empty bstr)
        .map([:]),                 // unprotected header (empty map)
        .null,                     // detached payload
        .byteString(Array(repeating: 0xAA, count: 64)) // 64-byte dummy signature
    ])

    let docRequestCBOR: CBOR = .map([
        .utf8String("itemsRequest"): itemsRequestDataItem,
        .utf8String("readerAuth"): readerAuth
    ])

    let deviceRequestCBOR: CBOR = .map([
        .utf8String("version"): .utf8String("1.0"),
        .utf8String("docRequests"): .array([docRequestCBOR])
    ])

    return Data(deviceRequestCBOR.encode())
}

/// Builds a DeviceRequest whose ItemsRequest additionally carries a `requestInfo` map,
/// then encodes it to CBOR bytes.
///
/// The verifier's `ItemsRequest` model does not populate `requestInfo` (MVP). To exercise the
/// conformance checks for the optional `requestInfo` element, we generate the base DocRequest from the
/// verifier models and then splice in a `requestInfo` map at the CBOR level, preserving the
/// model-generated `docType` and `nameSpaces`.
///
/// - Returns: The CBOR-encoded DeviceRequest bytes with a requestInfo-bearing ItemsRequest.
func makeDeviceRequestDataWithRequestInfo() throws -> Data {
    let group = try #require(
        AttributeGroup(
            docType: .mdl,
            mdlAttributes: [
                .init(attribute: .familyName, intentToRetain: false)
            ]
        ),
        "AttributeGroup must be constructable with at least one attribute"
    )
    let deviceRequest = DeviceRequest(docRequests: [DocRequest(with: group)])

    // Decode the model-generated DeviceRequest to extract the ItemsRequest bytes
    let originalBytes = [UInt8](Data(deviceRequest.toCBOR().encode()))
    let decoded = try #require(try CBOR.decode(originalBytes))
    guard case .map(let drMap) = decoded,
          case .array(let docRequests) = drMap[.utf8String("docRequests")],
          let firstDocReq = docRequests.first,
          case .map(let docReqMap) = firstDocReq,
          case .tagged(.encodedCBORDataItem, .byteString(let itemsBytes)) = docReqMap[.utf8String("itemsRequest")]
    else {
        Issue.record("Failed to extract ItemsRequest from model-generated DeviceRequest")
        return Data()
    }

    // Decode the inner ItemsRequest and add requestInfo
    let itemsDecoded = try #require(try CBOR.decode(itemsBytes))
    guard case .map(let itemsPairs) = itemsDecoded else {
        Issue.record("ItemsRequest must be a map")
        return Data()
    }

    // Build a new ItemsRequest map with requestInfo added
    var newItemsPairs = itemsPairs
    newItemsPairs[.utf8String("requestInfo")] = .map([
        .utf8String("purpose"): .utf8String("age verification")
    ])

    // Re-encode ItemsRequest, wrap in Tag(24, bstr(...)), rebuild DeviceRequest
    let newItemsBytes = CBOR.map(newItemsPairs).encode()
    let newDocRequest: CBOR = .map([
        .utf8String("itemsRequest"): .tagged(.encodedCBORDataItem, .byteString(newItemsBytes))
    ])
    let newDeviceRequest: CBOR = .map([
        .utf8String("version"): .utf8String("1.0"),
        .utf8String("docRequests"): .array([newDocRequest])
    ])

    return Data(newDeviceRequest.encode())
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
