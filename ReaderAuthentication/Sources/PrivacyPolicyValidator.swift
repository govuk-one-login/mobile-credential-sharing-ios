import ExchangeFormat
import Foundation
import SwiftASN1
import X509

/// R5: Extracts and validates the DVS privacy-policy URL from a verified Reader
/// leaf certificate, and extracts the subject `organizationName`.
///
/// This runs entirely offline. It does not download the policy page or inspect
/// its contents. On any failure it throws
/// ``ReaderAuthenticationFailure/privacyPolicyURLInvalid``.
enum PrivacyPolicyValidator {

    /// Maximum permitted length of the raw privacy-policy URI value.
    private static let maxURLLength = 2048

    static func validate(
        docRequest: RequestedDocument,
        verifiedReaderLeaf: Certificate
    ) throws -> AuthenticatedReaderRequest {

        // 1. Find the SIA extension on the leaf.
        guard let siaExtension = verifiedReaderLeaf.extensions[oid: .siaExtension] else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // Decode SIA (same shape as AIA: SEQUENCE OF AccessDescription).
        guard let sia = try? SubjectInformationAccess(siaExtension) else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // Find the AccessDescription for the privacy-policy access method OID,
        // and read its URI (accessLocation must be a uniformResourceIdentifier).
        guard let rawURL = sia.descriptions
            .first(where: { $0.accessMethod == .privacyPolicyAccessMethod })
            .flatMap({ description -> String? in
                guard case .uniformResourceIdentifier(let uri) = description.accessLocation else {
                    return nil
                }
                return uri
            })
        else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // 2. Validate the raw URL offline.
        let url = try parseAndValidate(rawURL: rawURL)

        // 3. Extract organizationName (O) from the subject DN — no validation.
        let organizationName = verifiedReaderLeaf.subject
            .flatMap { $0 }
            .first(where: { $0.type == .RDNAttributeType.organizationName })
            .flatMap { String($0.value) }

        // 4. Return the request with its validated URL and org name.
        return AuthenticatedReaderRequest(
            docRequest: docRequest,
            privacyPolicyURL: url,
            organizationName: organizationName
        )
    }

    /// Validates the raw URI string against every required rule and returns the
    /// parsed `URL`, preserving the exact validated absolute ASCII string.
    private static func parseAndValidate(rawURL: String) throws -> URL {
        // Length (count characters of the raw value).
        guard rawURL.count <= maxURLLength else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // ASCII only, no spaces.
        guard rawURL.allSatisfy({ $0.isASCII && $0 != " " }) else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // Parses as a native URL. Use URLComponents so we can inspect parts
        // without any network activity.
        guard let components = URLComponents(string: rawURL) else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // Scheme: HTTPS, case-insensitive.
        guard components.scheme?.lowercased() == "https" else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // Host: non-empty. (ASCII punycode is implied by the ASCII-only check
        // above; a Unicode label would have failed the ASCII rule already.)
        guard let host = components.host, !host.isEmpty else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // No user information (rejects user:pass@ and user@).
        guard components.user == nil, components.password == nil else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        // Preserve the exact validated absolute ASCII string.
        guard let url = URL(string: rawURL) else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }

        return url
    }
}

// MARK: - Subject Information Access

/// Minimal decoder for the Subject Information Access (SIA) extension.
///
/// SIA shares the ASN.1 structure of Authority Information Access:
/// `SEQUENCE SIZE (1..MAX) OF AccessDescription`, where
/// `AccessDescription ::= SEQUENCE { accessMethod OBJECT IDENTIFIER, accessLocation GeneralName }`.
///
/// swift-certificates ships `AuthorityInformationAccess` but not an SIA type,
/// so we parse the extension value directly.
struct SubjectInformationAccess {

    struct AccessDescription {
        let accessMethod: ASN1ObjectIdentifier
        let accessLocation: GeneralName
    }

    let descriptions: [AccessDescription]

    /// Decode from an opaque extension, verifying the OID is the SIA OID.
    init(_ ext: Certificate.Extension) throws {
        guard ext.oid == .siaExtension else {
            throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
        }
        let syntax = try AccessDescriptionsSyntax(derEncoded: ext.value)
        self.descriptions = syntax.descriptions
    }
}

/// Decodes the body of an SIA extension: an ordered list of access
/// descriptions.
///
/// Corresponds to the ASN.1 `SEQUENCE OF AccessDescription`.
private struct AccessDescriptionsSyntax: DERImplicitlyTaggable {
    static var defaultIdentifier: ASN1Identifier { .sequence }

    let descriptions: [SubjectInformationAccess.AccessDescription]

    init(derEncoded rootNode: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
        self.descriptions = try DER.sequence(
            of: AccessDescriptionSyntax.self,
            identifier: identifier,
            rootNode: rootNode
        ).map { SubjectInformationAccess.AccessDescription(
            accessMethod: $0.accessMethod,
            accessLocation: $0.accessLocation
        ) }
    }

    func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
        // Decode-only.
        throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
    }
}

/// A single access description: an access-method identifier paired with the
/// location where that information can be found.
///
/// Corresponds to the ASN.1 `AccessDescription ::= SEQUENCE { accessMethod
/// OBJECT IDENTIFIER, accessLocation GeneralName }`.
private struct AccessDescriptionSyntax: DERImplicitlyTaggable {
    static var defaultIdentifier: ASN1Identifier { .sequence }

    let accessMethod: ASN1ObjectIdentifier
    let accessLocation: GeneralName

    init(accessMethod: ASN1ObjectIdentifier, accessLocation: GeneralName) {
        self.accessMethod = accessMethod
        self.accessLocation = accessLocation
    }

    init(derEncoded rootNode: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
        self = try DER.sequence(rootNode, identifier: identifier) { nodes in
            let accessMethod = try ASN1ObjectIdentifier(derEncoded: &nodes)
            guard let locationNode = nodes.next() else {
                throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
            }
            let accessLocation = try GeneralName(derEncoded: locationNode)
            return AccessDescriptionSyntax(accessMethod: accessMethod, accessLocation: accessLocation)
        }
    }

    func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
        // Decode-only.
        throw ReaderAuthenticationFailure.privacyPolicyURLInvalid
    }
}

// MARK: - OIDs

private extension ASN1ObjectIdentifier {
    /// Subject Information Access extension OID (1.3.6.1.5.5.7.1.11).
    static let siaExtension: ASN1ObjectIdentifier = [1, 3, 6, 1, 5, 5, 7, 1, 11]

    /// DVS privacy-policy access method OID (1.3.6.1.4.1.66559.1.1).
    static let privacyPolicyAccessMethod: ASN1ObjectIdentifier = [1, 3, 6, 1, 4, 1, 66_559, 1, 1]
}
