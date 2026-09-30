import Foundation

/// Typed failures for Reader Authentication.
///
/// Consumers receive these failures when Reader Authentication cannot succeed.
/// Each case represents a distinct, non-recoverable failure and maps COSE and
/// privacy-metadata failures onto stable identifiers.
public enum ReaderAuthenticationFailure: Error, Equatable, Sendable {
    /// The `readerAuth` field was missing from the `DocRequest`.
    case readerAuthMissing

    /// The cryptographic COSE signature on Reader Authentication was invalid.
    case invalidReaderSignature

    /// The COSE_Sign1 structure or `x5chain` header was malformed.
    case malformedReaderAuth

    /// The algorithm used in Reader Authentication is not supported.
    case unsupportedReaderAuthAlgorithm

    /// The Reader certificate chain is untrusted, expired, or violates profile rules.
    case untrustedReaderCertificate

    /// The privacy-policy SIA extension entry or URL violates validation rules.
    case privacyPolicyURLInvalid

    /// The decrypted `DeviceRequest` bytes could not be decoded.
    case malformedDeviceRequest
}
