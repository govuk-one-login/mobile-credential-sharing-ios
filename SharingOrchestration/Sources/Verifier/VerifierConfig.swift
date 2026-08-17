import Foundation
import Security
import SharingCryptoService

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
    public let trustedIssuerCertificate: SecCertificate

    /// Creates a new verifier configuration.
    /// - Parameters:
    ///   - attributeRequest: The attribute group specifying which data elements to request.
    ///   - trustedIssuerCertificate: The root certificate of the trusted issuing authority.
    public init(
        attributeRequest: AttributeGroup,
        trustedIssuerCertificate: SecCertificate
    ) {
        self.attributeRequest = attributeRequest
        self.trustedIssuerCertificate = trustedIssuerCertificate
    }
}
