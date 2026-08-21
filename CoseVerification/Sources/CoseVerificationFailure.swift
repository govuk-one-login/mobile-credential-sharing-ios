import Foundation

/// Typed failures for COSE_Sign1 verification.
///
/// Consumers receive these failures when a verification operation cannot succeed.
/// Each case represents a distinct, non-recoverable verification problem.
/// Callers map these to their own domain-specific failure types
/// (e.g. `DocumentVerificationFailure`, `ReaderAuthenticationFailure`).
///
/// The component does not retain or mutate caller-owned inputs.
public enum CoseVerificationFailure: Error, Equatable, Sendable {
    /// The ECDSA signature does not verify against the signing key,
    /// or the `x5t` hash does not match the leaf certificate.
    case invalidSignature

    /// The certificate chain does not validate to the provided trusted root,
    /// or a revocation check fails.
    case untrustedCertificate

    /// The protected header algorithm is not supported (e.g. not ES256),
    /// `x5t` does not select SHA-256, or the certificate uses a weak hash (SHA-1, MD5).
    case unsupportedAlgorithm

    /// The input bytes are not a valid COSE_Sign1 four-element CBOR array,
    /// payload presence does not match the verification mode,
    /// `x5bag` is present, `x5chain` or `x5t` is in a prohibited header location,
    /// `x5chain` is malformed, or a required `x5t` is missing or malformed.
    case malformedCoseSign1

    /// The `x5chain` header parameter is not present in the unprotected header
    /// for a chain-based verification call.
    case missingX5Chain

    /// A certificate in the chain does not conform to the expected profile.
    /// The associated `reason` provides a diagnostic string indicating which check failed
    /// (e.g. "KeyUsage: digitalSignature not present", "EKU: required OID missing").
    /// Callers do not branch on the reason — it is for logging and debugging.
    case certificateProfileViolation(reason: String)
}
