import ExchangeFormat
import Foundation
import SwiftCBOR

/// Shared fixtures for building `RequestedDocument` values in Orchestration
/// tests, mirroring the shape Reader Authentication produces for the selected
/// candidate.
enum RequestedDocumentFixtures {

    /// Wraps a minimal `ItemsRequest` map as `#6.24(bstr .cbor ItemsRequest)`.
    private static func tag24ItemsRequest(
        docType: String,
        nameSpaces: [String: [String: Bool]]
    ) -> Data {
        var nameSpacesMap: [CBOR: CBOR] = [:]
        for (namespace, elements) in nameSpaces {
            var elementsMap: [CBOR: CBOR] = [:]
            for (identifier, intentToRetain) in elements {
                elementsMap[.utf8String(identifier)] = .boolean(intentToRetain)
            }
            nameSpacesMap[.utf8String(namespace)] = .map(elementsMap)
        }
        let inner: CBOR = .map([
            .utf8String("docType"): .utf8String(docType),
            .utf8String("nameSpaces"): .map(nameSpacesMap)
        ])
        let tagged = CBOR.tagged(.encodedCBORDataItem, .byteString(inner.encode()))
        return Data(tagged.encode())
    }

    /// Builds a `RequestedDocument` for the given docType and namespaces.
    static func make(
        docType: String = "org.iso.18013.5.1.mDL",
        nameSpaces: [String: [String: Bool]] = [:],
        rawReaderAuth: Data? = nil
    ) -> RequestedDocument {
        let tag24 = tag24ItemsRequest(docType: docType, nameSpaces: nameSpaces)
        // Force-try is acceptable in a test fixture building known-valid bytes.
        // swiftlint:disable:next force_try
        let itemsRequestBytes = try! ItemsRequestBytes(from: tag24)
        return RequestedDocument(
            itemsRequest: ParsedItemsRequest(docType: docType, nameSpaces: nameSpaces),
            itemsRequestBytes: itemsRequestBytes,
            rawReaderAuth: rawReaderAuth
        )
    }
}
