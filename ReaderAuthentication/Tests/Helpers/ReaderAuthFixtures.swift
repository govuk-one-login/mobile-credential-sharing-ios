import Crypto
import ExchangeFormat
import Foundation
import SwiftASN1
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

    /// A structurally valid detached COSE_Sign1 `[protected, unprotected, payload, signature]`.
    /// Content is irrelevant to decode-level tests; it only needs to be present.
    private static func sampleReaderAuth() -> CBOR {
        .array([
            .byteString([]),
            .map([:]),
            .null,
            .byteString(Array(repeating: 0xAA, count: 64))
        ])
    }

    /// Builds complete encoded `DeviceRequest` CBOR bytes for the given ordered
    /// docTypes. Each `docRequest` carries a valid Tag-24 `itemsRequest` and
    /// (by default) a structurally valid `readerAuth`, so the bytes decode
    /// cleanly via `DecodedDeviceRequest(encodedCBOR:)`.
    static func encodedDeviceRequest(
        docTypes: [String],
        includeReaderAuth: Bool = true,
        version: String = "1.0"
    ) -> Data {
        let docRequests: [CBOR] = docTypes.map { docType in
            let inner: CBOR = .map([
                .utf8String("docType"): .utf8String(docType),
                .utf8String("nameSpaces"): .map([:])
            ])
            var pairs: [CBOR: CBOR] = [
                .utf8String("itemsRequest"): .tagged(.encodedCBORDataItem, .byteString(inner.encode()))
            ]
            if includeReaderAuth {
                pairs[.utf8String("readerAuth")] = sampleReaderAuth()
            }
            return .map(pairs)
        }
        let request: CBOR = .map([
            .utf8String("version"): .utf8String(version),
            .utf8String("docRequests"): .array(docRequests)
        ])
        return Data(request.encode())
    }

    /// A valid DER-encoded self-signed X.509 EC P-256 certificate (CN=Test).
    /// `Certificate` type requirement in model tests.
    static func testCertificate() -> Certificate {
        let derBase64 =
        // swiftlint:disable:next line_length
            "MIIBczCCARmgAwIBAgIUWl8BgTTkJid7Z0dGO73JZA0NO+AwCgYIKoZIzj0EAwIwDzENMAsGA1UEAwwEVGVzdDAeFw0yNjA4MjAxNDM0NTRaFw0yNzA4MjAxNDM0NTRaMA8xDTALBgNVBAMMBFRlc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQ6F3EjAbeQFpr4mQcnL1gs0qa/6daNtd82eP/gLphdoBsrYE+WXy4sP0WfKqWFwIrOFI2fUMgP/fAIYMnad8kFo1MwUTAdBgNVHQ4EFgQUYZp7dpBZCGIoUb99qrxp/o9K7+MwHwYDVR0jBBgwFoAUYZp7dpBZCGIoUb99qrxp/o9K7+MwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNIADBFAiBXKGO7oizQofRlnHlXhPWHjGNmEH9uIGqxkGLUb7eGrgIhAMc4j4nqE6XLxfwx0eZdvGXhxiV1W212G7qm3KY1H7du"

        guard let derData = Data(base64Encoded: derBase64),
              let certificate = try? Certificate(derEncoded: Array(derData)) else {
            fatalError("Failed to create test certificate — DER data is invalid")
        }
        return certificate
    }
}

// MARK: - SIA leaf certificates

extension ReaderAuthFixtures {
    /// One SIA `AccessDescription`: an access-method OID paired with a location.
    struct AccessEntry {
        let accessMethod: ASN1ObjectIdentifier
        let accessLocation: AccessLocation

        /// A privacy-policy entry whose URI is `rawURI`.
        static func privacyPolicy(uri rawURI: String) -> AccessEntry {
            AccessEntry(accessMethod: privacyPolicyAccessMethodOID, accessLocation: .uri(rawURI))
        }

        /// A privacy-policy entry whose location is a non-URI GeneralName.
        static func privacyPolicy(dnsName: String) -> AccessEntry {
            AccessEntry(accessMethod: privacyPolicyAccessMethodOID, accessLocation: .dnsName(dnsName))
        }
    }
    
    /// The access-location shape for a single SIA `AccessDescription`.
    enum AccessLocation {
        /// A `uniformResourceIdentifier` GeneralName carrying the given string.
        case uri(String)
        /// A `dNSName` GeneralName — the valid-but-wrong location kind.
        case dnsName(String)
        /// A `uniformResourceIdentifier` GeneralName whose IA5String content is
        /// the given raw bytes verbatim.
        ///
        /// This bypasses `ASN1IA5String`'s ASCII validation on encode so a test
        /// can plant non-ASCII content — mirroring a malformed certificate
        /// arriving over the wire rather than one built by the library.
        case rawURIBytes([UInt8])
    }

    /// The DVS privacy-policy access-method OID (`1.3.6.1.4.1.66559.1.1`).
    static let privacyPolicyAccessMethodOID: ASN1ObjectIdentifier = [1, 3, 6, 1, 4, 1, 66_559, 1, 1]

    /// The Subject Information Access extension OID (`1.3.6.1.5.5.7.1.11`).
    static let siaExtensionOID: ASN1ObjectIdentifier = [1, 3, 6, 1, 5, 5, 7, 1, 11]

    /// Builds a real, self-signed P-256 leaf certificate for privacy-policy
    /// validation tests.
    ///
    /// - Parameters:
    ///   - organizationName: value for the subject `organizationName` (O)
    ///     attribute, or `nil` to omit it.
    ///   - commonName: value for the subject `commonName` (CN) attribute.
    ///   - siaEntries: SIA `AccessDescription` entries to encode, or `nil` to
    ///     omit the SIA extension entirely.
    static func leafCertificate(
        organizationName: String? = "Government Digital Service",
        commonName: String = "Test ReaderAuth Leaf",
        siaEntries: [AccessEntry]? = [.privacyPolicy(uri: "https://example.gov.uk/privacy")]
    ) throws -> Certificate {
        let key = P256.Signing.PrivateKey()

        var attributes: [RelativeDistinguishedName.Attribute] = [
            .init(type: .RDNAttributeType.commonName, utf8String: commonName)
        ]
        if let organizationName {
            attributes.append(.init(type: .RDNAttributeType.organizationName, utf8String: organizationName))
        }
        let name = try DistinguishedName(attributes)

        var extensions: [Certificate.Extension] = []
        if let siaEntries {
            extensions.append(try siaExtension(for: siaEntries))
        }

        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(key.publicKey),
            notValidBefore: Date(timeIntervalSince1970: 1_790_000_000),
            notValidAfter: Date(timeIntervalSince1970: 1_810_000_000),
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions(extensions),
            issuerPrivateKey: Certificate.PrivateKey(key)
        )
    }

    /// DER-encodes the given SIA entries into a `Certificate.Extension`.
    ///
    /// SIA shares AIA's structure: `SEQUENCE OF AccessDescription`, where
    /// `AccessDescription ::= SEQUENCE { accessMethod OID, accessLocation GeneralName }`.
    private static func siaExtension(for entries: [AccessEntry]) throws -> Certificate.Extension {
        var serializer = DER.Serializer()
        try serializer.appendConstructedNode(identifier: .sequence) { coder in
            for entry in entries {
                try coder.appendConstructedNode(identifier: .sequence) { innerCoder in
                    try innerCoder.serialize(entry.accessMethod)
                    switch entry.accessLocation {
                    case .uri(let uri):
                        try innerCoder.serialize(GeneralName.uniformResourceIdentifier(uri))
                    case .dnsName(let name):
                        try innerCoder.serialize(GeneralName.dnsName(name))
                    case .rawURIBytes(let bytes):
                        // GeneralName uniformResourceIdentifier is context-specific
                        // tag [6], primitive, with IA5String content. Write the raw
                        // content bytes directly so non-ASCII bytes survive encoding.
                        innerCoder.appendPrimitiveNode(
                            identifier: ASN1Identifier(tagWithNumber: 6, tagClass: .contextSpecific)
                        ) { content in
                            content.append(contentsOf: bytes)
                        }
                    }
                }
            }
        }
        return Certificate.Extension(
            oid: siaExtensionOID,
            critical: false,
            value: serializer.serializedBytes[...]
        )
    }
}
