import Foundation
import SwiftCBOR

/// The detached COSE payload authenticating a Reader request:
/// `#6.24(bstr .cbor ["ReaderAuthentication", SessionTranscript, ItemsRequestBytes])`.
///
/// Verifier and Holder must produce identical bytes, so the transcript and
/// request are spliced in unchanged; only the array header is emitted here and
/// SwiftCBOR applies the Tag 24 framing.
public enum ReaderAuthenticationBytes {

    private static let readerAuthentication = "ReaderAuthentication"

    /// CBOR definite-length array(3) header (major type 4 | length 3).
    private static let arrayHeaderThreeElements: [UInt8] = [0x83]

    /// - Parameters:
    ///   - untaggedSessionTranscriptBytes: Exact untagged `SessionTranscript`
    ///     array bytes from `CryptoService`, spliced in as element 1.
    ///   - itemsRequestBytes: Complete Tag 24 `ItemsRequest`, spliced in as
    ///     element 2 (and used identically in the transmitted `DocRequest`).
    /// - Returns: The Tag 24 encoded `ReaderAuthenticationBytes`.
    /// - Throws: `.invalidTag24` for a malformed request; `.malformedStructure`
    ///   if the transcript is not one complete item; `.trailingData` if bytes
    ///   remain after it.
    public static func bytes(
        untaggedSessionTranscriptBytes: Data,
        itemsRequestBytes: ItemsRequestBytes
    ) throws -> Data {
        try ItemsRequestBytes.validateTag24Shape(itemsRequestBytes.bytes)
        try requireSingleCompleteItem(untaggedSessionTranscriptBytes)

        let readerAuthenticationArray: [UInt8] = arrayHeaderThreeElements
            + CBOR.utf8String(readerAuthentication).encode()
            + [UInt8](untaggedSessionTranscriptBytes)
            + [UInt8](itemsRequestBytes.bytes)

        return Data(
            CBOR.tagged(.encodedCBORDataItem, .byteString(readerAuthenticationArray)).encode()
        )
    }

    /// One complete CBOR item, no trailing data. The re-encode length check is
    /// valid only for canonical inputs; EF2 must instead read the byte offsets
    /// of each item so it can copy the exact original bytes it received.
    private static func requireSingleCompleteItem(_ data: Data) throws {
        let raw = [UInt8](data)
        guard let item = try? CBOR.decode(raw) else {
            throw ExchangeFormatError.malformedStructure
        }
        guard item.encode().count == raw.count else {
            throw ExchangeFormatError.trailingData
        }
    }
}
