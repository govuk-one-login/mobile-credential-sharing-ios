@testable import CoseVerification
import CryptoKit
import Foundation
import Security
import SwiftCBOR

/// A fully-encoded detached COSE_Sign1 plus the key needed to verify it.
struct DetachedCoseSign1Fixture {
    let coseSign1Bytes: Data
    let detachedPayload: Data
    let publicKey: SecKey
}

/// Builds an untagged four-element detached COSE_Sign1 (null payload), signed over the
/// caller-supplied payload with a fresh P-256 key.
///
/// Overrides support negative vectors: `protectedHeaderForSigStructure` signs over different
/// bytes than embedded, `signatureOverride` injects malformed/non-verifying signatures, and
/// `publicKeyOverride` returns a mismatched or incompatible verification key.
func makeDetachedCoseSign1(
    protectedHeader: Data = es256ProtectedHeader,
    unprotectedHeaderBytes: [UInt8] = [0xA0],
    detachedPayload: Data = Data([0xDE, 0xAD, 0xBE, 0xEF]),
    protectedHeaderForSigStructure: Data? = nil,
    signingKey: P256.Signing.PrivateKey = P256.Signing.PrivateKey(),
    signatureOverride: Data? = nil,
    publicKeyOverride: SecKey? = nil
) throws -> DetachedCoseSign1Fixture {
    let sigStructure = SigStructureBuilder.build(
        protectedHeaderBytes: protectedHeaderForSigStructure ?? protectedHeader,
        payload: detachedPayload
    )

    let signatureBytes: [UInt8]
    if let signatureOverride {
        signatureBytes = [UInt8](signatureOverride)
    } else {
        signatureBytes = [UInt8](try signingKey.signature(for: sigStructure).rawRepresentation)
    }

    let coseSign1 = cborCoseSign1(
        protectedHeader: [UInt8](protectedHeader),
        unprotectedHeader: unprotectedHeaderBytes,
        payload: .detached,
        signature: signatureBytes
    )

    return DetachedCoseSign1Fixture(
        coseSign1Bytes: coseSign1,
        detachedPayload: detachedPayload,
        publicKey: try publicKeyOverride ?? secKey(from: signingKey.publicKey)
    )
}
