import Foundation
import SharingOrchestration

/// The ReaderAuth certificate profiles selectable in the Verifier test app.
/// Ported from the Android `ReaderAuthOption`. The chain excludes the root; only the leaf key is bundled.
enum ReaderAuthProfileOption: CaseIterable {
    /// Valid leaf certificate with a well-formed DVS privacy policy URL (Subject Information Access).
    case valid
    /// Otherwise-valid leaf certificate that is missing the privacy policy URL SIA value.
    case missingPrivacyPolicyURL
    /// Leaf certificate that is invalid due to a NameConstraints violation.
    case invalidNameConstraints

    static let `default`: ReaderAuthProfileOption = .valid

    /// Per-profile metadata. `leafCertificate` is a `.der` resource; `leafKey` is a `.pem` resource.
    private var descriptor: (displayName: String, leafCertificate: String, leafKey: String) {
        switch self {
        case .valid:
            return (
                "Valid",
                "reader_valid_x509_leaf_certificate",
                "reader_valid_x509_leaf_key"
            )
        case .missingPrivacyPolicyURL:
            return (
                "Missing privacy policy URL",
                "reader_x509_leaf_without_privacy_policy",
                "reader_x509_leaf_without_privacy_policy_key"
            )
        case .invalidNameConstraints:
            return (
                "Invalid name constraints",
                "reader_x509_leaf_with_invalid_organisation",
                "reader_x509_leaf_with_invalid_organisation_key"
            )
        }
    }

    /// Label shown in the selection UI.
    var displayName: String { descriptor.displayName }

    /// Bundle resource name (without extension) of the shared intermediate certificate (DER encoded).
    private static let intermediateCertificateResource = "reader_intermediate_x509_certificate"

    /// Loads the provisioned material for this profile into a session-ready ``ReaderAuthProfile``.
    ///
    /// Resources are carried as opaque bytes; any parsing/decoding is left to the consumer.
    ///
    /// - Parameter bundle: The bundle to load resources from. Defaults to `.main`.
    /// - Throws: ``ReaderAuthProfileError`` if a resource is missing.
    /// - Returns: A ``ReaderAuthProfile`` holding the leaf + intermediate chain (root excluded)
    ///   and the leaf private key.
    func load(from bundle: Bundle = .main) throws -> ReaderAuthProfile {
        ReaderAuthProfile(
            leafCertificateDER: try Self.loadResource(descriptor.leafCertificate, extension: "der", from: bundle),
            intermediateCertificateDER: try Self.loadResource(Self.intermediateCertificateResource, extension: "der", from: bundle),
            leafPrivateKeyPEM: try Self.loadResource(descriptor.leafKey, extension: "pem", from: bundle)
        )
    }

    /// Loads a bundled resource as raw bytes.
    private static func loadResource(
        _ resource: String,
        extension ext: String,
        from bundle: Bundle
    ) throws -> Data {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            throw ReaderAuthProfileError.resourceNotFound("\(resource).\(ext)")
        }
        return try Data(contentsOf: url)
    }
}

enum ReaderAuthProfileError: Error, Equatable {
    case resourceNotFound(String)
}
