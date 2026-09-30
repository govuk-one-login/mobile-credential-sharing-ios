import ExchangeFormat
import Foundation
import SwiftCBOR
import X509

/// Shared fixtures for ReaderAuthentication model tests.
enum ReaderAuthFixtures {

    /// Wraps a minimal `ItemsRequest` map as `#6.24(bstr .cbor ItemsRequest)`.
    private static func tag24ItemsRequest(docType: String) -> Data {
        let inner: CBOR = .map([
            .utf8String("docType"): .utf8String(docType),
            .utf8String("nameSpaces"): .map([:])
        ])
        let tagged = CBOR.tagged(.encodedCBORDataItem, .byteString(inner.encode()))
        return Data(tagged.encode())
    }

    /// Builds a `RequestedDocument` for the given docType, with an optional
    /// `rawReaderAuth` blob.
    static func requestedDocument(
        docType: String = "org.iso.18013.5.1.mDL",
        rawReaderAuth: Data? = nil
    ) throws -> RequestedDocument {
        let tag24 = tag24ItemsRequest(docType: docType)
        return RequestedDocument(
            itemsRequest: ParsedItemsRequest(docType: docType, nameSpaces: [:]),
            itemsRequestBytes: try ItemsRequestBytes(from: tag24),
            rawReaderAuth: rawReaderAuth
        )
    }

    /// A valid DER-encoded self-signed X.509 EC P-256 certificate (CN=Test).
    /// Not a meaningful trust anchor — it exists only to satisfy the
    /// `Certificate` type requirement in model tests.
    static func testCertificate() -> Certificate {
        let derBase64 =
            "MIIBczCCARmgAwIBAgIUWl8BgTTkJid7Z0dGO73JZA0NO+AwCgYIKoZIzj0EAwIw" +
            "DzENMAsGA1UEAwwEVGVzdDAeFw0yNjA4MjAxNDM0NTRaFw0yNzA4MjAxNDM0NTRa" +
            "MA8xDTALBgNVBAMMBFRlc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQ6F3Ej" +
            "AbeQFpr4mQcnL1gs0qa/6daNtd82eP/gLphdoBsrYE+WXy4sP0WfKqWFwIrOFI2f" +
            "UMgP/fAIYMnad8kFo1MwUTAdBgNVHQ4EFgQUYZp7dpBZCGIoUb99qrxp/o9K7+Mw" +
            "HwYDVR0jBBgwFoAUYZp7dpBZCGIoUb99qrxp/o9K7+MwDwYDVR0TAQH/BAUwAwEB" +
            "/zAKBggqhkjOPQQDAgNIADBFAiBXKGO7oizQofRlnHlXhPWHjGNmEH9uIGqxkGLU" +
            "b7eGrgIhAMc4j4nqE6XLxfwx0eZdvGXhxiV1W212G7qm3KY1H7du"

        guard let derData = Data(base64Encoded: derBase64),
              let certificate = try? Certificate(derEncoded: Array(derData)) else {
            fatalError("Failed to create test certificate — DER data is invalid")
        }
        return certificate
    }
}
