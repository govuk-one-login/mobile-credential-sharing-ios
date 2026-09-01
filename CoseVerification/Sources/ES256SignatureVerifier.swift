import CryptoKit
import Foundation
import Security

enum ES256SignatureVerifier {
    
    static func verify(
        sigStructure: Data,
        signature: Data,
        publicKey: SecKey
    ) throws {

        var error: Unmanaged<CFError>?
        guard let externalRepresentation = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        let p256Key: P256.Signing.PublicKey
        do {
            p256Key = try P256.Signing.PublicKey(x963Representation: externalRepresentation as Data)
        } catch {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

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
}
