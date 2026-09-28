@testable import ExchangeFormat
import Foundation
import SwiftCBOR
import Testing

/// Tests for the byte-preserving `DeviceRequest` decoder (DCMAW-23073).
///
/// The decoder must:
///   - return the requested documents in the order they were received,
///   - preserve each document's exact Tag 24 `itemsRequestBytes` and optional
///     `rawReaderAuth`, and
///   - reject structurally invalid input with an `ExchangeFormatError` and no
///     partial result.

@Suite("DeviceRequest Decoder Tests")
struct DeviceRequestDecoderTests {

    // MARK: - AC1: order and authenticated bytes preserved

    @Test("AC1: decoding preserves order and exact Tag 24 / readerAuth bytes")
    func preservesOrderAndAuthenticatedBytes() throws {
        let firstItems = Self.itemsRequest(docType: "org.iso.18013.5.1.mDL")
        let secondItems = Self.itemsRequest(docType: "org.iso.23220.2.photoid.1")
        let readerAuth = Self.validReaderAuth()

        let request = Self.deviceRequest(docRequests: [
            Self.docRequest(itemsRequest: firstItems, readerAuth: readerAuth),
            Self.docRequest(itemsRequest: secondItems)
        ])
        let bytes = Data(request.encode())

        let decoded = try DecodedDeviceRequest(encodedCBOR: bytes)

        #expect(decoded.version == "1.0")
        #expect(decoded.documents.count == 2)

        // Order preserved: first doc is the mDL, second is the photo ID.
        #expect(decoded.documents[0].itemsRequest.docType == "org.iso.18013.5.1.mDL")
        #expect(decoded.documents[1].itemsRequest.docType == "org.iso.23220.2.photoid.1")

        // itemsRequestBytes equal the exact original Tag 24 encoding.
        #expect(decoded.documents[0].itemsRequestBytes.bytes == Data(Self.tag24(firstItems).encode()))
        #expect(decoded.documents[1].itemsRequestBytes.bytes == Data(Self.tag24(secondItems).encode()))

        // rawReaderAuth equals the exact original item, present only on the first.
        #expect(decoded.documents[0].rawReaderAuth == Data(readerAuth.encode()))
        #expect(decoded.documents[1].rawReaderAuth == nil)
    }

    @Test("AC1: preserved bytes are the received bytes, not a re-encoding")
    func preservedBytesAreSourceSlice() throws {
        let items = Self.itemsRequest()
        let request = Self.deviceRequest(docRequests: [Self.docRequest(itemsRequest: items)])
        let bytes = Data(request.encode())

        let decoded = try DecodedDeviceRequest(encodedCBOR: bytes)
        let preserved = decoded.documents[0].itemsRequestBytes.bytes

        // The preserved bytes must appear verbatim as a contiguous slice of the input.
        #expect(bytes.range(of: preserved) != nil)
    }

    // MARK: - AC2: missing ReaderAuth remains valid

    @Test("AC2: a DocRequest without readerAuth decodes with rawReaderAuth nil")
    func missingReaderAuthIsValid() throws {
        let items = Self.itemsRequest()
        let request = Self.deviceRequest(docRequests: [Self.docRequest(itemsRequest: items)])
        let bytes = Data(request.encode())

        let decoded = try DecodedDeviceRequest(encodedCBOR: bytes)

        #expect(decoded.documents.count == 1)
        #expect(decoded.documents[0].rawReaderAuth == nil)
        #expect(decoded.documents[0].itemsRequestBytes.bytes == Data(Self.tag24(items).encode()))
    }

    // MARK: - AC3: wrong-shaped COSE remains available

    @Test("AC3: a complete but COSE-invalid readerAuth is preserved unchanged")
    func wrongShapedCoseIsPreserved() throws {
        // One complete CBOR item, but not a valid COSE_Sign1 shape (a bare map).
        let malformedCose: CBOR = .map([.utf8String("not"): .utf8String("cose")])
        let items = Self.itemsRequest()
        let request = Self.deviceRequest(docRequests: [
            Self.docRequest(itemsRequest: items, readerAuth: malformedCose)
        ])
        let bytes = Data(request.encode())

        let decoded = try DecodedDeviceRequest(encodedCBOR: bytes)

        // No COSE-shape failure: the raw item is returned exactly as received.
        #expect(decoded.documents[0].rawReaderAuth == Data(malformedCose.encode()))
    }

    // MARK: - AC4: invalid structure returns no partial request

    @Test("AC4: trailing data after the top-level item is rejected")
    func trailingDataRejected() throws {
        let items = Self.itemsRequest()
        var bytes = Data(Self.deviceRequest(docRequests: [Self.docRequest(itemsRequest: items)]).encode())
        bytes.append(0xFF) // extra byte beyond one complete item

        #expect(throws: ExchangeFormatError.trailingData) {
            try DecodedDeviceRequest(encodedCBOR: bytes)
        }
    }

    @Test("AC4: a missing required field is rejected")
    func missingRequiredFieldRejected() throws {
        // docRequests present, version missing.
        let request: CBOR = .map([
            .utf8String("docRequests"): .array([Self.docRequest(itemsRequest: Self.itemsRequest())])
        ])
        #expect(throws: ExchangeFormatError.missingRequiredField) {
            try DecodedDeviceRequest(encodedCBOR: Data(request.encode()))
        }
    }

    @Test("AC4: a DocRequest missing itemsRequest is rejected")
    func docRequestMissingItemsRequestRejected() throws {
        let request: CBOR = .map([
            .utf8String("version"): .utf8String("1.0"),
            .utf8String("docRequests"): .array([.map([:])])
        ])
        #expect(throws: ExchangeFormatError.missingRequiredField) {
            try DecodedDeviceRequest(encodedCBOR: Data(request.encode()))
        }
    }

    @Test("AC4: an empty docRequests array is rejected")
    func emptyDocRequestsRejected() throws {
        let request = Self.deviceRequest(docRequests: [])
        #expect(throws: ExchangeFormatError.malformedStructure) {
            try DecodedDeviceRequest(encodedCBOR: Data(request.encode()))
        }
    }

    @Test("AC4: a duplicate key in the request map is rejected")
    func duplicateKeyRejected() throws {
        // Hand-encode a map with two identical "version" keys, since SwiftCBOR's
        // CBOR.map dictionary cannot represent duplicates.
        // map(3) { "version":"1.0", "version":"1.0", "docRequests":[docReq] }
        let docReq = Self.docRequest(itemsRequest: Self.itemsRequest()).encode()
        var bytes: [UInt8] = [0xA3] // map with 3 pairs
        bytes += CBOR.utf8String("version").encode() + CBOR.utf8String("1.0").encode()
        bytes += CBOR.utf8String("version").encode() + CBOR.utf8String("1.0").encode()
        bytes += CBOR.utf8String("docRequests").encode() + CBOR.array([]).encode()
        // Replace the empty array with a real one-element array.
        bytes = Array(bytes.dropLast()) // drop the 0x80 empty-array byte
        bytes += ([0x81] + docReq)       // array(1) [docReq]

        #expect(throws: ExchangeFormatError.duplicateKey) {
            try DecodedDeviceRequest(encodedCBOR: Data(bytes))
        }
    }

    @Test("AC4: a non-CBOR / truncated input is rejected as malformed")
    func truncatedInputRejected() throws {
        // A map header claiming 2 pairs but no content.
        let bytes = Data([0xA2])
        #expect(throws: ExchangeFormatError.self) {
            try DecodedDeviceRequest(encodedCBOR: bytes)
        }
    }

    @Test("AC4: itemsRequest that is not a Tag 24 wrapper is rejected")
    func itemsRequestNotTag24Rejected() throws {
        // itemsRequest present but as a bare map rather than #6.24(bstr ...).
        let docReq: CBOR = .map([.utf8String("itemsRequest"): Self.itemsRequest()])
        let request = Self.deviceRequest(docRequests: [docReq])
        #expect(throws: ExchangeFormatError.invalidTag24) {
            try DecodedDeviceRequest(encodedCBOR: Data(request.encode()))
        }
    }

    // MARK: - Fixture builders

    /// Wraps an `ItemsRequest` CBOR value as `#6.24(bstr .cbor ItemsRequest)`.
    private static func tag24(_ inner: CBOR) -> CBOR {
        .tagged(.encodedCBORDataItem, .byteString(inner.encode()))
    }

    /// A minimal valid `ItemsRequest` map.
    private static func itemsRequest(docType: String = "org.iso.18013.5.1.mDL") -> CBOR {
        .map([
            .utf8String("docType"): .utf8String(docType),
            .utf8String("nameSpaces"): .map([
                .utf8String("org.iso.18013.5.1"): .map([
                    .utf8String("family_name"): .boolean(true)
                ])
            ])
        ])
    }

    /// A structurally valid COSE_Sign1 array `[protected, unprotected, payload, signature]`.
    private static func validReaderAuth() -> CBOR {
        .array([
            .byteString([]),
            .map([:]),
            .null,
            .byteString(Array(repeating: 0xAA, count: 64))
        ])
    }

    private static func docRequest(itemsRequest: CBOR, readerAuth: CBOR? = nil) -> CBOR {
        var pairs: [CBOR: CBOR] = [.utf8String("itemsRequest"): tag24(itemsRequest)]
        if let readerAuth {
            pairs[.utf8String("readerAuth")] = readerAuth
        }
        return .map(pairs)
    }

    private static func deviceRequest(docRequests: [CBOR], version: String = "1.0") -> CBOR {
        .map([
            .utf8String("version"): .utf8String(version),
            .utf8String("docRequests"): .array(docRequests)
        ])
    }
}
