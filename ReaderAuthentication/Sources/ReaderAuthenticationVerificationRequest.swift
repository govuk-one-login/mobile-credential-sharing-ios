import Foundation
import X509

/// The immutable set of inputs Holder orchestration supplies to Reader
/// Authentication for one inbound request.
///
/// Bundling the inputs into one value keeps the ``ReaderAuthenticating``
/// contract stable as the Holder path evolves, and makes the authentication
/// call a single owned snapshot of the transaction's inputs.
public struct ReaderAuthenticationVerificationRequest: Sendable {

    /// The complete decrypted `DeviceRequest` plaintext bytes received over BLE.
    public let encodedDeviceRequest: Data

    /// The exact active untagged session transcript bytes, as supplied by
    /// CryptoService. ReaderAuth is reconstructed and verified against these
    /// bytes, so they must match the transcript the Reader signed.
    public let untaggedSessionTranscriptBytes: Data

    /// The non-empty, de-duplicated set of trusted Reader CA certificates
    /// captured for this Holder journey. Every certificate is passed to
    /// CoseVerification; no preferred root is selected.
    public let trustedReaderCertificates: [Certificate]

    /// The document types supported by the product. A decoded request whose
    /// `docType` is absent from this set is not a candidate.
    public let supportedDocumentTypes: Set<String>

    public init(
        encodedDeviceRequest: Data,
        untaggedSessionTranscriptBytes: Data,
        trustedReaderCertificates: [Certificate],
        supportedDocumentTypes: Set<String>
    ) {
        self.encodedDeviceRequest = encodedDeviceRequest
        self.untaggedSessionTranscriptBytes = untaggedSessionTranscriptBytes
        self.trustedReaderCertificates = trustedReaderCertificates
        self.supportedDocumentTypes = supportedDocumentTypes
    }
}
