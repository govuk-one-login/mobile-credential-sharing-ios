import CryptoKit
import Foundation
import Security

/// Verifies COSE_Sign1 ES256 signatures (ECDSA over P-256 with SHA-256).
/// It proves the holder of the corresponding private key signed the exact `Sig_structure`
/// bytes. It does not establish whether the key is trusted — that is the caller's concern.
enum ES256SignatureVerifier {

    /// Verifies an ES256 signature over the given `Sig_structure` bytes.
    /// - Throws: `.unsupportedAlgorithm` if the key is not a P-256 key;
    ///   `.invalidSignature` if the signature is not a 64-byte raw `r || s` value or does not verify.
    static func verify(
        sigStructure: Data,
        signature: Data,
        publicKey: SecKey
    ) throws {
        let p256Key = try p256PublicKey(from: publicKey)

        // ES256 requires a 64-byte raw r || s signature; any other encoding is invalid.
        let ecdsaSignature: P256.Signing.ECDSASignature
        do {
            ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        } catch {
            throw CoseVerificationFailure.invalidSignature
        }

        guard p256Key.isValidSignature(ecdsaSignature, for: sigStructure) else {
            throw CoseVerificationFailure.invalidSignature
        }
    }

    /// Converts a `SecKey` into a CryptoKit `P256.Signing.PublicKey`, mapping any
    /// non-P-256 key to `unsupportedAlgorithm`.
    private static func p256PublicKey(from secKey: SecKey) throws -> P256.Signing.PublicKey {
        var error: Unmanaged<CFError>?
        // For EC keys this yields the X9.63 point.
        guard let externalRepresentation = SecKeyCopyExternalRepresentation(secKey, &error) else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        do {
            // The X9.63 init is the enforcement point: it accepts only a valid 65-byte
            // point on P-256, rejecting RSA, P-384, and off-curve keys alike.
            return try P256.Signing.PublicKey(x963Representation: externalRepresentation as Data)
        } catch {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }
    }
}
