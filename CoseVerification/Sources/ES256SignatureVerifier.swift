import CryptoKit
import Foundation
import Security

enum ES256SignatureVerifier {
    static func verify(
        sigStructure: Data,
        signature: Data,
        publicKey: SecKey
    ) throws {
        let p256Key = try p256PublicKey(from: publicKey)

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

    private static func p256PublicKey(from secKey: SecKey) throws -> P256.Signing.PublicKey {
        var error: Unmanaged<CFError>?
        guard let externalRepresentation = SecKeyCopyExternalRepresentation(secKey, &error) else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        do {
            return try P256.Signing.PublicKey(x963Representation: externalRepresentation as Data)
        } catch {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }
    }
}
