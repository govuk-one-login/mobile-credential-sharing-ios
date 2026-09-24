import CryptoKit
import Foundation

/// Verifies COSE_Sign1 ES256 signatures (ECDSA over P-256 with SHA-256).
/// It proves the holder of the corresponding private key signed the exact `Sig_structure`
/// bytes. It does not establish whether the key is trusted — that is the caller's concern.
///
/// The key is typed as a `P256.Signing.PublicKey`, so an ES256-incompatible key (RSA, P-384,
/// off-curve) cannot reach this verifier: that algorithm gate is enforced upstream, at the point
/// the public key is constructed.
enum ES256SignatureVerifier {

    /// Verifies an ES256 signature over the given `Sig_structure` bytes.
    /// - Throws: `.invalidSignature` if the signature is not a 64-byte raw `r || s` value or does
    ///   not verify.
    static func verify(
        sigStructure: Data,
        signature: Data,
        publicKey: P256.Signing.PublicKey
    ) throws {
        // ES256 requires a 64-byte raw r || s signature; any other encoding is invalid.
        let ecdsaSignature: P256.Signing.ECDSASignature
        do {
            ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        } catch {
            throw CoseVerificationFailure.invalidSignature
        }

        guard publicKey.isValidSignature(ecdsaSignature, for: sigStructure) else {
            throw CoseVerificationFailure.invalidSignature
        }
    }
}
