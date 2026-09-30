import Foundation
import X509

/// High-level component contract for Reader Authentication orchestration.
///
/// Authenticates decrypted `DeviceRequest` bytes, filters supported candidate
/// document types, verifies candidate signatures and privacy-policy metadata,
/// and selects the first passing candidate.
public protocol ReaderAuthenticationVerifying: Sendable {
    /// Authenticates the decrypted `DeviceRequest` bytes and selects the first
    /// candidate passing verification.
    ///
    /// - Parameters:
    ///   - decryptedDeviceRequestBytes: The complete plaintext request bytes
    ///     received over BLE.
    ///   - untaggedSessionTranscriptBytes: The active untagged session
    ///     transcript bytes.
    ///   - supportedDocumentTypes: The document types supported by the product.
    ///   - trustedReaderCertificates: The non-empty list of trusted Reader CA
    ///     certificates.
    /// - Returns: ``ReaderAuthenticationOutcome/success(_:)`` or
    ///   ``ReaderAuthenticationOutcome/unfulfillable``.
    /// - Throws: ``ReaderAuthenticationFailure`` if every candidate fails
    ///   verification or decoding fails.
    func authenticateDeviceRequest(
        decryptedDeviceRequestBytes: Data,
        untaggedSessionTranscriptBytes: Data,
        supportedDocumentTypes: [String],
        trustedReaderCertificates: [Certificate]
    ) async throws -> ReaderAuthenticationOutcome
}

/// Outcome of Reader Authentication processing.
public enum ReaderAuthenticationOutcome: Sendable, Equatable {
    /// A candidate passed authentication and was selected.
    case success(AuthenticatedReaderRequest)

    /// No candidate matched product-supported document types.
    case unfulfillable
}
