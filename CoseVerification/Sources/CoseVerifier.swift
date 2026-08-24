import Foundation
import Security

/// A verifier for COSE_Sign1 structures as defined in RFC 9052.
///
/// `CoseVerifier` provides three verification operations corresponding to the
/// ISO 18013-5 trust objects:
///
/// - **Chain-based attached** (`verifyAttached`): For IssuerAuth. The payload is
///   embedded in the COSE_Sign1 structure. The certificate chain is validated
///   against a caller-provided trusted root.
///
/// - **Chain-based detached** (`verifyDetached` with `trustedRoot`): For ReaderAuth.
///   The payload is constructed externally by the caller and supplied separately.
///   The certificate chain is validated against a caller-provided trusted root.
///
/// - **Key-based detached** (`verifyDetached` with `publicKey`): For DeviceSignature.
///   The payload is constructed externally by the caller. The signature is verified
///   against a bare EC public key already established as trustworthy by a prior
///   chain-based verification.
///
/// All operations throw ``CoseVerificationFailure`` on any check failure.
/// The component does not retain or mutate caller-owned inputs.
/// Callers pass raw bytes and platform Security primitives (`SecCertificate`, `SecKey`).
/// The public API does not expose decoded COSE models.
public protocol CoseVerifier: Sendable {
    /// Verifies a COSE_Sign1 structure with an attached payload using certificate chain trust.
    ///
    /// Use this for IssuerAuth verification. The COSE_Sign1 structure must contain:
    /// - A protected header with `alg` (ES256) and `x5t` (SHA-256 thumbprint)
    /// - An unprotected header with `x5chain` (leaf-first certificate chain)
    /// - An embedded payload (the MSO bytes)
    /// - An ECDSA signature
    ///
    /// - Parameters:
    ///   - coseSign1Bytes: The raw CBOR-encoded COSE_Sign1 bytes.
    ///   - trustedRoot: The trusted root certificate to anchor the chain validation.
    /// - Returns: A ``CoseVerificationResult`` containing the verified leaf certificate and
    ///   the attached payload.
    /// - Throws: ``CoseVerificationFailure`` if any verification step fails.
    func verifyAttached(
        coseSign1Bytes: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult

    /// Verifies a COSE_Sign1 structure with a detached payload using certificate chain trust.
    ///
    /// Use this for ReaderAuth verification. The COSE_Sign1 structure must contain:
    /// - A protected header with `alg` (ES256) and `x5t` (SHA-256 thumbprint)
    /// - An unprotected header with `x5chain` (leaf-first certificate chain)
    /// - A nil payload field (the payload is supplied separately)
    /// - An ECDSA signature
    ///
    /// - Parameters:
    ///   - coseSign1Bytes: The raw CBOR-encoded COSE_Sign1 bytes.
    ///   - detachedPayload: The externally-constructed payload bytes
    ///     (e.g. `ReaderAuthenticationBytes`).
    ///   - trustedRoot: The trusted root certificate to anchor the chain validation.
    /// - Returns: A ``CoseVerificationResult`` containing the verified leaf certificate.
    ///   The `payload` field is nil.
    /// - Throws: ``CoseVerificationFailure`` if any verification step fails.
    func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult

    /// Verifies a COSE_Sign1 structure with a detached payload using a known public key.
    ///
    /// Use this for DeviceSignature verification. No certificate chain validation
    /// is performed — the trust in the public key was already established by a prior
    /// chain-based verification of IssuerAuth.
    ///
    /// - Parameters:
    ///   - coseSign1Bytes: The raw CBOR-encoded COSE_Sign1 bytes.
    ///   - detachedPayload: The externally-constructed payload bytes
    ///     (e.g. `DeviceAuthenticationBytes`).
    ///   - publicKey: The EC public key to verify the signature against.
    /// - Throws: ``CoseVerificationFailure`` if the structure is malformed,
    ///   the algorithm is unsupported, or the signature does not verify.
    ///   Only `invalidSignature`, `unsupportedAlgorithm`, and `malformedCoseSign1`
    ///   are possible for this operation.
    func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        publicKey: SecKey
    ) throws
}
