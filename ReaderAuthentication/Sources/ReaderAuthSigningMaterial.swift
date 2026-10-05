import CryptoKit
import Foundation

/// The session-provided Reader signing material: a leaf-first, root-excluded DER certificate chain
/// and the matching leaf ES256 (P-256) private key. Provisioned by DCMAW-21734 (`ReaderAuthProfile`)
/// and adapted into this SDK-internal type by orchestration. Element 0 is the leaf.
public struct ReaderAuthSigningMaterial {
    public let certificateChain: [Data]

    /// The leaf's P-256 signing key, matching the public key in `certificateChain[0]`.
    public let leafPrivateKey: P256.Signing.PrivateKey

    public init(certificateChain: [Data], leafPrivateKey: P256.Signing.PrivateKey) {
        self.certificateChain = certificateChain
        self.leafPrivateKey = leafPrivateKey
    }

    /// Builds signing material from a leaf-first DER chain and a PEM-encoded leaf private key.
    public init(certificateChain: [Data], leafPrivateKeyPEM: String) throws {
        let key: P256.Signing.PrivateKey
        do {
            key = try P256.Signing.PrivateKey(pemRepresentation: leafPrivateKeyPEM)
        } catch {
            throw ReaderAuthGenerationFailure.invalidSigningCredential
        }
        self.init(certificateChain: certificateChain, leafPrivateKey: key)
    }
}
