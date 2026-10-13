import Foundation

/// A parsed, `Sendable` summary of an `ItemsRequest` — just enough to later
/// work out which credential can satisfy the request.
///
/// This is deliberately a small projection of the decoded request, not the raw
/// SwiftCBOR value. Two reasons:
///   - The authoritative bytes are kept separately in
///     ``RequestedDocument/itemsRequestBytes``.
///   - SwiftCBOR's `CBOR` type is not `Sendable`, so it must not cross this
///     module's public boundary.
public struct ParsedItemsRequest: Sendable, Equatable, Hashable {

    /// The requested `docType` (e.g. `org.iso.18013.5.1.mDL`).
    public let docType: String

    /// The requested element identifiers, grouped by namespace, each mapped to
    /// its `intentToRetain` flag.
    public let nameSpaces: [String: [String: Bool]]

    public init(docType: String, nameSpaces: [String: [String: Bool]]) {
        self.docType = docType
        self.nameSpaces = nameSpaces
    }
}

/// One requested document from a decoded `DeviceRequest`. It keeps the exact
/// bytes that ISO 18013-5 needs for Reader Authentication.
///
/// Each document carries both a parsed summary (to decide which credential can
/// satisfy the request) and the untouched original bytes (for signature
/// verification):
///
/// - ``itemsRequest`` — the parsed `ItemsRequest` summary, used to match a
///   credential to the request.
/// - ``itemsRequestBytes`` — the complete original `#6.24(bstr .cbor ItemsRequest)`
///   value exactly as received. This is the byte range the Reader signed, so it
///   is never re-encoded.
/// - ``rawReaderAuth`` — the complete original `readerAuth` item exactly as
///   received, or `nil` if it was absent. Its COSE structure is not interpreted
///   here (that is `CoseVerification`'s job); even a structurally complete but
///   COSE-invalid item is kept unchanged.
public struct RequestedDocument: Sendable, Equatable, Hashable {

    /// The parsed `ItemsRequest` summary (from the item inside the Tag 24 wrapper).
    public let itemsRequest: ParsedItemsRequest

    /// The complete original Tag 24 `ItemsRequest` bytes, kept verbatim.
    public let itemsRequestBytes: ItemsRequestBytes

    /// The complete original `readerAuth` item, kept verbatim, or `nil`.
    public let rawReaderAuth: Data?

    public init(
        itemsRequest: ParsedItemsRequest,
        itemsRequestBytes: ItemsRequestBytes,
        rawReaderAuth: Data?
    ) {
        self.itemsRequest = itemsRequest
        self.itemsRequestBytes = itemsRequestBytes
        self.rawReaderAuth = rawReaderAuth
    }
}

/// A decoded `DeviceRequest`: its requested documents in the order received,
/// with each document's authenticated bytes kept intact.
///
/// Build one with ``init(encodedCBOR:)``. This is the byte-preserving
/// replacement for the older `SharingCryptoService.DeviceRequest` decoder.
/// Switching existing callers over to it is tracked separately and is not done
/// here.
public struct DecodedDeviceRequest: Sendable, Equatable {

    /// The protocol version string from the request map.
    public let version: String

    /// The requested documents, in the exact order received.
    public let documents: [RequestedDocument]

    public init(version: String, documents: [RequestedDocument]) {
        self.version = version
        self.documents = documents
    }
}
