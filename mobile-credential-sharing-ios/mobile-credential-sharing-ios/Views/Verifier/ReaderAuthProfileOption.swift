import Foundation
import SharingOrchestration

/// The ReaderAuth certificate profiles selectable in the Verifier test app.
/// The chain excludes the root; only the leaf key is bundled.
enum ReaderAuthProfileOption: CaseIterable {
    /// Valid leaf certificate with a well-formed DVS privacy policy URL (Subject Information Access).
    case valid
    /// Otherwise-valid leaf certificate that is missing the privacy policy URL SIA value.
    case missingPrivacyPolicyURL
    /// Leaf certificate that is invalid due to a NameConstraints violation.
    case invalidNameConstraints
    /// DVS-issued profile for the lower (dev) environment. Pipeline-provisioned via
    /// `POST /issue-reader-cert`; the committed assets are unprovisioned placeholders.
    case dvsLowerEnv
    /// DVS-issued profile for the integration environment. Pipeline-provisioned via
    /// `POST /issue-reader-cert`; the committed assets are unprovisioned placeholders.
    case dvsIntegration

    static let `default`: ReaderAuthProfileOption = .valid

    /// Bundle resource name (without extension) of the shared intermediate certificate (DER encoded).
    private static let intermediateCertificateResource = "reader_intermediate_x509_certificate"

    /// Whether this profile is backed by a single, whole leaf-first chain file provisioned by the
    /// build pipeline (`true`), or by separate mock leaf + shared-intermediate resources (`false`).
    var isPipelineProvisioned: Bool {
        switch self {
        case .dvsLowerEnv, .dvsIntegration:
            return true
        case .valid, .missingPrivacyPolicyURL, .invalidNameConstraints:
            return false
        }
    }

    /// Per-profile metadata.
    /// - For mock profiles, `leafCertificate` is a `.der` resource and `leafKey` is a `.pem` resource.
    /// - For DVS profiles, `leafCertificate` is the whole leaf-first chain `.der` resource and
    ///   `leafKey` is the leaf `.pem` resource.
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
        case .dvsLowerEnv:
            return (
                "Wallet Test App (Lower Env)",
                "reader_dvs_dev_chain",
                "reader_dvs_dev_leaf_key"
            )
        case .dvsIntegration:
            return (
                "Wallet Test App (Integration)",
                "reader_dvs_integration_chain",
                "reader_dvs_integration_leaf_key"
            )
        }
    }

    /// The bundle resource name (without extension) of the leaf certificate asset.
    /// For DVS profiles this is the whole chain file; its first certificate is the leaf.
    var leafCertificateResource: String { descriptor.leafCertificate }

    /// Label shown in the selection UI.
    var displayName: String { descriptor.displayName }

    /// Loads this profile's bundled certificate chain and leaf key into a ``ReaderAuthProfile``.
    ///
    /// - Mock profiles load a single leaf `.der` + the shared intermediate `.der` (root excluded).
    /// - DVS profiles load a single whole leaf-first chain `.der`, splitting any concatenated
    ///   certificates into an arbitrary-length leaf-first array.
    /// - Throws: ``ReaderAuthProfileError`` if a resource is missing or an issued chain is empty.
    /// - Returns: A ``ReaderAuthProfile`` holding the leaf-first chain (root excluded) and the
    ///   leaf private key.
    func load(from bundle: Bundle = .main) throws -> ReaderAuthProfile {
        let leafKeyPEM = try Self.loadResource(descriptor.leafKey, extension: "pem", from: bundle)

        if isPipelineProvisioned {
            let chainData = try Self.loadResource(descriptor.leafCertificate, extension: "der", from: bundle)
            let certificates = Self.splitDERCertificates(chainData)
            guard !certificates.isEmpty else {
                throw ReaderAuthProfileError.emptyCertificateChain(descriptor.leafCertificate)
            }
            return ReaderAuthProfile(
                certificateChainDER: certificates,
                leafPrivateKeyPEM: leafKeyPEM
            )
        }

        return ReaderAuthProfile(
            leafCertificateDER: try Self.loadResource(descriptor.leafCertificate, extension: "der", from: bundle),
            intermediateCertificateDER: try Self.loadResource(Self.intermediateCertificateResource, extension: "der", from: bundle),
            leafPrivateKeyPEM: leafKeyPEM
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

    /// Splits a buffer of one or more concatenated DER-encoded X.509 certificates into their
    /// individual DER elements, preserving order (leaf first). Each certificate is a top-level
    /// ASN.1 `SEQUENCE` (tag `0x30`) whose definite length prefix determines its byte span.
    ///
    /// Returns an empty array if the buffer does not begin with a parseable DER certificate (for
    /// example an unprovisioned placeholder), so callers fail closed.
    static func splitDERCertificates(_ data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var certificates: [Data] = []
        var index = 0

        while index < bytes.count {
            // Each certificate starts with a SEQUENCE tag.
            guard bytes[index] == 0x30 else { break }
            guard index + 1 < bytes.count else { break }

            let lengthByte = bytes[index + 1]
            let contentLength: Int
            let headerLength: Int

            if lengthByte & 0x80 == 0 {
                // Short form: the length is this single byte.
                contentLength = Int(lengthByte)
                headerLength = 2
            } else {
                // Long form: the low 7 bits give the number of subsequent length bytes.
                let lengthFieldCount = Int(lengthByte & 0x7F)
                guard lengthFieldCount > 0, index + 1 + lengthFieldCount < bytes.count else { break }
                var value = 0
                for offset in 0..<lengthFieldCount {
                    value = (value << 8) | Int(bytes[index + 2 + offset])
                }
                contentLength = value
                headerLength = 2 + lengthFieldCount
            }

            let totalLength = headerLength + contentLength
            guard index + totalLength <= bytes.count else { break }

            certificates.append(Data(bytes[index..<(index + totalLength)]))
            index += totalLength
        }

        return certificates
    }
}

enum ReaderAuthProfileError: Error, Equatable {
    case resourceNotFound(String)
    case emptyCertificateChain(String)
}
