import Foundation

/// The typed, terminal failure raised by `ReaderAuthGenerator`. Each case ends the Verifier journey:
/// no `DeviceRequest` is created, encrypted, or transmitted, and signing is not retried.
public enum ReaderAuthGenerationFailure: Error, Equatable, Sendable {
    /// The chain is empty/malformed/self-signed, the order is invalid, or the leaf key is not a
    /// decodable P-256 key.
    case invalidSigningCredential

    /// ECDSA P-256 / SHA-256 signing over the `Sig_structure` failed.
    case signingFailed
}
