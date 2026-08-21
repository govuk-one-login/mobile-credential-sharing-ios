import Foundation
import Security

/// The result of a successful chain-based COSE_Sign1 verification.
///
/// Returned by `CoseVerifier.verifyAttached` and `CoseVerifier.verifyDetached`
/// (chain-based overload). Contains the verified leaf certificate and optional
/// attached payload.
///
/// - Note: The key-based `verifyDetached` overload returns `Void` on success
///   because the caller already possesses the payload and public key.
///   The only question answered is "did the signature verify?".
public struct CoseVerificationResult: Sendable {
    /// The leaf certificate from the `x5chain` that was used to verify the signature.
    /// The certificate chain has been validated against the caller-provided trusted root.
    public let leafCertificate: SecCertificate

    /// The payload bytes from the COSE_Sign1 structure.
    /// Non-nil for attached verification (IssuerAuth); nil for detached verification
    /// (ReaderAuth), where the caller already possesses the payload.
    public let payload: Data?

    /// Creates a new verification result.
    /// - Parameters:
    ///   - leafCertificate: The verified leaf certificate from the x5chain.
    ///   - payload: The attached payload bytes, or nil for detached verification.
    public init(
        leafCertificate: SecCertificate,
        payload: Data?
    ) {
        self.leafCertificate = leafCertificate
        self.payload = payload
    }
}
