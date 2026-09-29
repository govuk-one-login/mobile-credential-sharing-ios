/// Stable reason identifiers for Reader Authentication failures.
///
/// Mirrors the Android `ReaderAuthenticationReason` contract so both platforms
/// map COSE and privacy-metadata failures onto the same identifiers.
public enum ReaderAuthenticationReason: Sendable, Equatable, CaseIterable {
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
