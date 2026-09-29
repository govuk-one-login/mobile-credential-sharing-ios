import Foundation
import SwiftCBOR

extension DecodedDeviceRequest {

    /// CBOR keys used by the `DeviceRequest` / `DocRequest` wire structures.
    private enum Key {
        static let version = "version"
        static let docRequests = "docRequests"
        static let itemsRequest = "itemsRequest"
        static let readerAuth = "readerAuth"
    }

    /// Decodes a `DeviceRequest` from its received CBOR bytes. For each requested
    /// document it keeps the exact `itemsRequestBytes` (a Tag 24 value) and the
    /// optional `rawReaderAuth`, so Reader Authentication can later verify the
    /// bytes that were signed.
    ///
    /// The decode runs in four steps, with all framing handled by
    /// ``CBORByteScanner`` (the one structural walker):
    /// 1. Check the input is exactly one complete top-level item.
    /// 2. Read the request map: a `version` text string and a non-empty
    ///    `docRequests` array.
    /// 3. For each `DocRequest`, slice out the exact bytes of `itemsRequest`
    ///    (a required Tag 24 value) and `readerAuth` (optional), without
    ///    re-encoding them.
    /// 4. Decode only the leaf values needed for the parsed summary.
    ///
    /// The input must satisfy these structural rules. Breaking any of them throws
    /// and produces no partial result:
    /// - Exactly one complete top-level item, with no trailing data.
    /// - The top level is a map with a `version` text string and a non-empty
    ///   `docRequests` array.
    /// - Each `docRequests` element is a map with a required `itemsRequest`
    ///   Tag 24 value (`#6.24(bstr .cbor ...)`) wrapping one complete item, plus
    ///   an optional `readerAuth`.
    /// - The maps this decoder reads (the request map and each DocRequest map)
    ///   must not repeat a key.
    ///
    /// The `readerAuth` item's COSE structure is not checked here: a structurally
    /// complete but COSE-invalid item is kept unchanged (`CoseVerification` is
    /// responsible for COSE). CBOR encodings that are valid but non-canonical are
    /// accepted, and their byte ranges are kept unchanged.
    ///
    /// - Parameter encodedCBOR: The complete received `DeviceRequest` bytes.
    /// - Throws: ``ExchangeFormatError`` describing the first structural failure.
    public init(encodedCBOR: Data) throws {
        let bytes = [UInt8](encodedCBOR)

        // 1. Require exactly one complete top-level item; reject trailing data.
        let topRange = try CBORByteScanner.scanItem(bytes, at: 0)
        guard topRange.end == bytes.count else {
            throw ExchangeFormatError.trailingData
        }

        // 2. Read the request map: version + docRequests.
        let requestFields = try Self.fieldRanges(bytes, at: 0)

        let version = try Self.textString(bytes, at: requestFields[Key.version])

        guard let docRequestsRange = requestFields[Key.docRequests] else {
            throw ExchangeFormatError.missingRequiredField
        }
        let docRequestRanges = try CBORByteScanner.arrayElements(bytes, at: docRequestsRange.start)
        guard !docRequestRanges.isEmpty else {
            throw ExchangeFormatError.malformedStructure
        }

        // 3 & 4. Decode each DocRequest, keeping its authenticated bytes intact.
        let documents = try docRequestRanges.map { element in
            try Self.decodeRequestedDocument(bytes, at: element.start)
        }

        self.init(version: version, documents: documents)
    }

    // MARK: - DocRequest

    private static func decodeRequestedDocument(_ bytes: [UInt8], at offset: Int) throws -> RequestedDocument {
        let fields = try fieldRanges(bytes, at: offset)

        // itemsRequest: required Tag 24 wrapper. Slice the exact original bytes,
        // then validate the wrapper shape without re-encoding.
        guard let itemsRange = fields[Key.itemsRequest] else {
            throw ExchangeFormatError.missingRequiredField
        }
        let itemsRequestData = Data(bytes[itemsRange.start..<itemsRange.end])
        let itemsRequestBytes = try ItemsRequestBytes(from: itemsRequestData)
        let itemsRequest = try parseItemsRequest(fromTag24: itemsRequestData)

        // readerAuth: optional. Keep the exact original item verbatim; its COSE
        // structure is not checked here.
        let rawReaderAuth = fields[Key.readerAuth].map { range in
            Data(bytes[range.start..<range.end])
        }

        return RequestedDocument(
            itemsRequest: itemsRequest,
            itemsRequestBytes: itemsRequestBytes,
            rawReaderAuth: rawReaderAuth
        )
    }

    /// Decodes the `ItemsRequest` held inside a Tag 24 wrapper into the
    /// `Sendable` ``ParsedItemsRequest`` summary used to match a credential.
    ///
    /// The embedded byte string must hold exactly one complete CBOR item.
    private static func parseItemsRequest(fromTag24 data: Data) throws -> ParsedItemsRequest {
        guard case .tagged(.encodedCBORDataItem, .byteString(let embedded))? =
                try? CBOR.decode([UInt8](data)) else {
            throw ExchangeFormatError.invalidTag24
        }
        let embeddedRange = try CBORByteScanner.scanItem(embedded, at: 0)
        guard embeddedRange.end == embedded.count,
              let cbor = try? CBOR.decode(embedded) else {
            throw ExchangeFormatError.invalidTag24
        }

        guard case .map(let fields) = cbor,
              case .utf8String(let docType)? = fields[.utf8String("docType")],
              case .map(let nameSpaceMap)? = fields[.utf8String("nameSpaces")] else {
            throw ExchangeFormatError.malformedStructure
        }

        var nameSpaces: [String: [String: Bool]] = [:]
        for (nameSpaceKey, elementsValue) in nameSpaceMap {
            guard case .utf8String(let nameSpace) = nameSpaceKey,
                  case .map(let elements) = elementsValue else {
                throw ExchangeFormatError.malformedStructure
            }
            var parsedElements: [String: Bool] = [:]
            for (elementKey, retainValue) in elements {
                guard case .utf8String(let identifier) = elementKey,
                      case .boolean(let intentToRetain) = retainValue else {
                    throw ExchangeFormatError.malformedStructure
                }
                parsedElements[identifier] = intentToRetain
            }
            nameSpaces[nameSpace] = parsedElements
        }

        return ParsedItemsRequest(docType: docType, nameSpaces: nameSpaces)
    }

    // MARK: - Map helpers

    /// Reads a definite-length map at `offset` (via ``CBORByteScanner``) into a
    /// lookup from text-string key to the byte range of its value. Every key must
    /// be a text string, and the map must not repeat a key.
    private static func fieldRanges(_ bytes: [UInt8], at offset: Int) throws -> [String: CBORByteScanner.ItemRange] {
        var fields: [String: CBORByteScanner.ItemRange] = [:]
        for entry in try CBORByteScanner.mapEntries(bytes, at: offset) {
            let key = try textString(bytes, at: entry.key)
            guard fields[key] == nil else {
                throw ExchangeFormatError.duplicateKey
            }
            fields[key] = entry.value
        }
        return fields
    }

    /// Decodes the item in `range` as a required CBOR text string.
    ///
    /// A `nil` range means the field was absent, which counts as a missing
    /// required field.
    private static func textString(_ bytes: [UInt8], at range: CBORByteScanner.ItemRange?) throws -> String {
        guard let range else {
            throw ExchangeFormatError.missingRequiredField
        }
        guard case .utf8String(let value)? = try? CBOR.decode(Array(bytes[range.start..<range.end])) else {
            throw ExchangeFormatError.malformedStructure
        }
        return value
    }
}
