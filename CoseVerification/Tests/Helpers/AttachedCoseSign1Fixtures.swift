@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
import X509

/// A fully-encoded attached IssuerAuth COSE_Sign1 plus the trusted root that anchors it.
///
/// Produced by ``AttachedIssuerAuthFixtures/make(_:)``. The COSE_Sign1 embeds the leaf-first
/// `x5chain` (unprotected) and the leaf `x5t` (protected), and its signature is computed over the
/// `Sig_structure` for the embedded payload with the leaf's private key.
struct AttachedIssuerAuthFixture {
    /// The encoded, untagged four-element attached COSE_Sign1.
    let coseSign1Bytes: Data
    /// The exact embedded payload bytes (the value a successful verification must return).
    let payload: Data
    /// The trusted root the caller supplies to `verifyAttached`.
    let trustedRoot: Certificate
    /// The DER of the signing leaf (first x5chain element), for `x5t` / substitution assertions.
    let leafDer: Data
}

/// Assembles a valid, current-dated IssuerAuth hierarchy and a signed attached COSE_Sign1.
///
/// The certificate validity windows straddle the present, so C7's default current-time expiry
/// policy accepts them without fixed-time injection. Individual `overrides` let a test flip exactly
/// one attribute to drive a single negative boundary while keeping every other check passing.
///
/// Shared certificate and header builders live in ``CoseSign1FixtureBuilder``; this type owns only
/// the IssuerAuth-specific concerns (embedded payload, IssuerAuth EKU, DN naming, and the fixture
/// struct it returns).
enum AttachedIssuerAuthFixtures {

    /// Knobs a negative test can flip; the defaults produce the AC1 success path.
    struct Overrides {
        /// Replace the protected header bytes (e.g. a non-ES256 `alg`) used both in the encoded
        /// COSE and the signed `Sig_structure`.
        var protectedHeader: Data = es256ProtectedHeader
        /// Omit the `x5chain` from the unprotected header entirely (drives `missingX5Chain`).
        var omitX5Chain = false
        /// Anchor against an unrelated root instead of the chain's real root (drives
        /// `untrustedCertificate`).
        var useWrongTrustedRoot = false
        /// Build the leaf without the IssuerAuth EKU `1.0.18013.5.1.2` (drives
        /// `certificateProfileViolation`).
        var omitIssuerAuthEKU = false
        /// Replace the signature with bytes that will not verify (drives `invalidSignature`).
        var tamperSignature = false
        /// Sign over — and embed — a different payload than the one the verifier is asked about;
        /// used to prove the returned/verified payload is exactly the embedded one.
        var payload = Data([0x01, 0x02, 0x03, 0x04])
    }

    static func make(_ overrides: Overrides = Overrides()) throws -> AttachedIssuerAuthFixture {
        // Root CA (self-signed), valid across the present.
        let rootKey = P256.Signing.PrivateKey()
        let rootName = try CoseSign1FixtureBuilder.name("Test Issuer Root")
        let root = try CoseSign1FixtureBuilder.caCertificate(
            subject: rootName, issuer: rootName, subjectKey: rootKey, issuerKey: rootKey
        )

        // An unrelated root, used only when a test wants an untrusted anchor.
        let wrongRootKey = P256.Signing.PrivateKey()
        let wrongRootName = try CoseSign1FixtureBuilder.name("Unrelated Root")
        let wrongRoot = try CoseSign1FixtureBuilder.caCertificate(
            subject: wrongRootName, issuer: wrongRootName, subjectKey: wrongRootKey, issuerKey: wrongRootKey
        )

        // IssuerAuth leaf signed by the root.
        let leafKey = P256.Signing.PrivateKey()
        let eku: [ASN1ObjectIdentifier] = overrides.omitIssuerAuthEKU ? [] : [[1, 0, 18013, 5, 1, 2]]
        let leaf = try CoseSign1FixtureBuilder.endEntityCertificate(
            subject: try CoseSign1FixtureBuilder.name("Test IssuerAuth Leaf"),
            issuer: rootName,
            subjectKey: leafKey,
            issuerKey: rootKey,
            eku: eku
        )
        let leafDer = try CoseSign1FixtureBuilder.der(of: leaf)

        // Protected header: alg (and, on the success path, x5t binding the leaf).
        let protectedHeaderBytes = try CoseSign1FixtureBuilder.protectedHeader(
            base: overrides.protectedHeader,
            leafDer: leafDer,
            includeX5t: overrides.protectedHeader == es256ProtectedHeader
        )

        // Unprotected header: leaf-first x5chain (unless the test omits it).
        let unprotectedHeaderBytes = overrides.omitX5Chain
            ? [UInt8](arrayLiteral: 0xA0)
            : CoseSign1FixtureBuilder.unprotectedHeaderWithX5Chain([leafDer])

        // Signature over the Sig_structure for the embedded payload with the leaf key.
        let sigStructure = SigStructureBuilder.build(
            protectedHeaderBytes: protectedHeaderBytes,
            payload: overrides.payload
        )
        let realSignature = [UInt8](try leafKey.signature(for: sigStructure).rawRepresentation)
        let signatureBytes = overrides.tamperSignature
            ? [UInt8](repeating: 0x2B, count: 64)
            : realSignature

        let coseSign1 = cborCoseSign1(
            protectedHeader: [UInt8](protectedHeaderBytes),
            unprotectedHeader: unprotectedHeaderBytes,
            payload: .attached([UInt8](overrides.payload)),
            signature: signatureBytes
        )

        return AttachedIssuerAuthFixture(
            coseSign1Bytes: coseSign1,
            payload: overrides.payload,
            trustedRoot: overrides.useWrongTrustedRoot ? wrongRoot : root,
            leafDer: leafDer
        )
    }
}
