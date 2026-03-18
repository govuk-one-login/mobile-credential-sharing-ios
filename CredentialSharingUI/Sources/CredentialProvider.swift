import Foundation

/// Protocol that the Consumer implements to provide credentials to the SDK.
/// The SDK invokes these methods after establishing a secure connection.
public protocol CredentialProvider {
    /// Query Credentials: The SDK invokes this method when the Verifier requests specific document types.
    /// The Consumer returns credentials from secure storage matching the requested types.
    /// Initially this will always return an array of exactly one element: the decrypted raw CBOR data
    /// for the user's mDL credential.
    func getCredentials(for request: CredentialRequest) async throws -> [Credential]
    
    /// Device Authentication (Remote Signing): The SDK constructs a `DeviceAuthentication` CBOR payload.
    /// This payload proves device possession and includes session transcripts to prevent replay attacks.
    /// The Consumer signs this payload using the credential's static device private key (Secure Enclave).
    func sign(payload: Data, documentID: String) async throws -> Data
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
