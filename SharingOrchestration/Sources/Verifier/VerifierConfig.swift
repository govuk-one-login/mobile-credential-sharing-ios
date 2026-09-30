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

/// ReaderAuth material for a session: the leaf + intermediate chain (`x5chain`, root excluded)
/// and the leaf private key. Carried as raw bytes to stay `Sendable` with no extra dependencies.
public struct ReaderAuthProfile: Sendable, Equatable {
    /// The `x5chain` (DER): leaf first, then intermediate. Root excluded.
    public let certificateChainDER: [Data]

    /// The leaf certificate, DER encoded.
    public let leafCertificateDER: Data

    /// The shared intermediate certificate, DER encoded.
    public let intermediateCertificateDER: Data

    /// The leaf private key, PEM-encoded.
    public let leafPrivateKeyPEM: Data

    public init(
        leafCertificateDER: Data,
        intermediateCertificateDER: Data,
        leafPrivateKeyPEM: Data
    ) {
        self.certificateChainDER = [leafCertificateDER, intermediateCertificateDER]
        self.leafCertificateDER = leafCertificateDER
        self.intermediateCertificateDER = intermediateCertificateDER
        self.leafPrivateKeyPEM = leafPrivateKeyPEM
    }
}
