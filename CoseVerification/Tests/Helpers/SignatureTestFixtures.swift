@testable import CoseVerification
import CryptoKit
import Foundation

/// The canonical ES256 protected header content: {1: -7} => A1 01 26.
let es256ProtectedHeader = Data([0xA1, 0x01, 0x26])

/// A P-256 key pair plus a valid raw ES256 signature over a given Sig_structure.
struct SignedFixture {
    let sigStructure: Data
    let rawSignature: Data        // 64-byte r || s
    let publicKey: P256.Signing.PublicKey
    let protectedHeader: Data
    let payload: Data
}

/// Builds the Sig_structure for the given protected header and payload, then signs it
/// with a fresh P-256 key, returning the signature and matching public key.
func makeSignedFixture(
    protectedHeader: Data = es256ProtectedHeader,
    payload: Data = Data([0xDE, 0xAD, 0xBE, 0xEF])
) throws -> SignedFixture {
    let privateKey = P256.Signing.PrivateKey()
    let sigStructure = SigStructureBuilder.build(
        protectedHeaderBytes: protectedHeader,
        payload: payload
    )
    let signature = try privateKey.signature(for: sigStructure)
    return SignedFixture(
        sigStructure: sigStructure,
        rawSignature: signature.rawRepresentation,
        publicKey: privateKey.publicKey,
        protectedHeader: protectedHeader,
        payload: payload
    )
}
