import Foundation

/// The result of processing an inbound `SessionEstablishment` on the Holder side.
///
/// CryptoService performs key derivation, decryption, and transcript
/// establishment, then hands back the complete decrypted request plaintext and
/// the exact untagged session transcript. The request bytes are not decoded
/// here; decoding and candidate selection are owned by Reader Authentication.
public struct ProcessedSessionEstablishment: Equatable, Sendable {

    /// The complete decrypted `DeviceRequest` plaintext bytes, exactly as
    /// received. Passed verbatim to Reader Authentication for decoding.
    public let decryptedRequestBytes: Data

    /// The exact untagged `SessionTranscript` bytes the Reader signed over.
    /// Used to reconstruct and verify Reader Authentication.
    public let untaggedSessionTranscriptBytes: Data

    public init(
        decryptedRequestBytes: Data,
        untaggedSessionTranscriptBytes: Data
    ) {
        self.decryptedRequestBytes = decryptedRequestBytes
        self.untaggedSessionTranscriptBytes = untaggedSessionTranscriptBytes
    }
}
