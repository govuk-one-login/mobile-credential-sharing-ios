import Foundation

/// Protocol that the Consumer implements to provide credentials to the SDK.
/// The SDK invokes these methods after establishing a secure connection.
@MainActor
public protocol CredentialProvider {
    /// Query Credentials: The SDK invokes this method when the Verifier requests specific document types.
    /// The Consumer returns credentials from secure storage matching the requested types.
    /// Initially this will always return an array of exactly one element: the decrypted raw CBOR data
    /// for the user's mDL credential.
    func getCredentials(for request: CredentialRequest) async throws -> [Credential]
    
    /// Device Authentication: The SDK constructs a COSE `Sig_structure` per RFC 9052 §4.4,
    /// wrapping the `DeviceAuthenticationBytes` as the payload. The `Sig_structure` binds the protected
    /// headers, external authenticated data, and payload into a single canonical byte string for signing.
    /// The Consumer signs this payload using the credential's static device private key (Secure Enclave).
    ///
    /// The Consumer must catch its internal errors and map them to `CredentialSigningError`:
    /// - `.recoverable`: The user explicitly cancelled the biometric/passcode prompt.
    ///   The session stays active and the user remains on the consent screen to retry or cancel.
    /// - `.unrecoverable`: Any other condition prevents signing.
    ///   The SDK terminates the session and displays a generic error.
    func sign(payload: Data, documentID: String) async throws(CredentialSigningError) -> Data
}

/// Represents a request for credentials from the Verifier.
public struct CredentialRequest {
    public let documentTypes: [String]
    
    public init(documentTypes: [String]) {
        self.documentTypes = documentTypes
    }
}

/// Represents a credential returned by the Consumer.
public struct Credential {
    public let id: String
    public let rawCredential: Data  // Raw CBOR-encoded credential data
    
    public init(id: String, rawCredential: Data) {
        self.id = id
        self.rawCredential = rawCredential
    }
}
