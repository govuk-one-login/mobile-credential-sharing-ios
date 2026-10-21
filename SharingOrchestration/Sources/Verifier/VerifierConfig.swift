import Foundation
import SharingCryptoService
import X509

/// Configuration provided by the host application to start a verifier journey.
///
/// Combines the attribute request (what data elements to request from the Holder)
/// with the trusted issuer root certificate (used to verify the credential's IssuerAuth signature).
///
/// Each journey requires a fresh `VerifierConfig` instance - the SDK holds no reference
/// to a previous journey's configuration after teardown.
public struct VerifierConfig: Sendable {
    /// The attributes to request from the Holder, including document type and namespace information.
    public let attributeRequest: AttributeGroup

    /// The trusted issuer root certificate used to anchor verification of the credential's IssuerAuth signature.
    public let trustedIssuerCertificate: Certificate

    /// The ReaderAuth certificate profile for the session. Optional so existing host integrations
    /// that do not yet perform ReaderAuth continue to compile.
    public let readerAuthProfile: ReaderAuthProfile?

    /// Creates a new verifier configuration.
    /// - Parameters:
    ///   - attributeRequest: The attribute group specifying which data elements to request.
    ///   - trustedIssuerCertificate: The root certificate of the trusted issuing authority.
    ///   - readerAuthProfile: The ReaderAuth certificate profile for the session. Defaults to `nil`.
    public init(
        attributeRequest: AttributeGroup,
        trustedIssuerCertificate: Certificate,
        readerAuthProfile: ReaderAuthProfile? = nil
    ) {
        self.attributeRequest = attributeRequest
        self.trustedIssuerCertificate = trustedIssuerCertificate
        self.readerAuthProfile = readerAuthProfile
    }
}

/// ReaderAuth material for a session: a leaf-first DER certificate chain (`x5chain`, root excluded)
/// and the leaf private key. Carried as raw bytes to stay `Sendable` with no extra dependencies.
///
/// The chain is leaf-first and of arbitrary length: element 0 is always the leaf, followed by any
/// intermediate certificates (root excluded). Mock profiles use the leaf + single-intermediate
/// convenience initializer; pipeline-provisioned DVS profiles supply the whole issued chain.
public struct ReaderAuthProfile: Sendable, Equatable {
    /// The `x5chain` (DER): leaf first, then any intermediates. Root excluded. Never empty.
    public let certificateChainDER: [Data]

    /// The leaf private key, PEM-encoded.
    public let leafPrivateKeyPEM: Data

    /// The leaf certificate, DER encoded. Always the first element of ``certificateChainDER``.
    public var leafCertificateDER: Data { certificateChainDER[0] }

    /// The single intermediate certificate, DER encoded, when the chain is exactly leaf +
    /// one intermediate (the mock-profile shape). `nil` for chains of any other length.
    public var intermediateCertificateDER: Data? {
        certificateChainDER.count == 2 ? certificateChainDER[1] : nil
    }

    /// Builds a profile from an arbitrary leaf-first DER chain (root excluded).
    /// - Parameters:
    ///   - certificateChainDER: Leaf-first DER certificate chain. Element 0 must be the leaf.
    ///     Must not be empty.
    ///   - leafPrivateKeyPEM: The leaf private key, PEM-encoded.
    public init(
        certificateChainDER: [Data],
        leafPrivateKeyPEM: Data
    ) {
        precondition(!certificateChainDER.isEmpty, "ReaderAuthProfile requires a non-empty chain")
        self.certificateChainDER = certificateChainDER
        self.leafPrivateKeyPEM = leafPrivateKeyPEM
    }

    /// Convenience initializer for the mock profiles: a leaf plus a single shared intermediate.
    public init(
        leafCertificateDER: Data,
        intermediateCertificateDER: Data,
        leafPrivateKeyPEM: Data
    ) {
        self.init(
            certificateChainDER: [leafCertificateDER, intermediateCertificateDER],
            leafPrivateKeyPEM: leafPrivateKeyPEM
        )
    }
}
