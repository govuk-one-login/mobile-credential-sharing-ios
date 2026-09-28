@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
import X509

/// A fully-encoded detached ReaderAuth COSE_Sign1 plus the trusted reader root that anchors it.
///
/// Produced by ``DetachedReaderAuthFixtures/make(_:)``. The COSE_Sign1 embeds the leaf-first
/// `x5chain` (unprotected) and the leaf `x5t` (protected), carries a `nil` payload field, and its
/// signature is computed over the `Sig_structure` for the *caller-supplied* detached payload with
/// the leaf's private key.
///
/// This mirrors ``AttachedIssuerAuthFixture`` but for the certificate-backed detached
/// (ReaderAuth) mode: the payload is not embedded, it is supplied separately to the verifier.
struct DetachedReaderAuthFixture {
    /// The encoded, untagged four-element detached COSE_Sign1 (null payload).
    let coseSign1Bytes: Data
    /// The detached payload bytes the caller supplies to `verifyDetached` separately from the COSE.
    let detachedPayload: Data
    /// The trusted reader root the caller supplies to `verifyDetached`.
    let trustedRoot: Certificate
    /// The DER of the signing reader leaf (first x5chain element), for `x5t` / substitution
    /// assertions.
    let leafDer: Data
}

/// Assembles a valid, current-dated ReaderAuth hierarchy and a signed detached COSE_Sign1.
///
/// The certificate validity windows straddle the present, so C8's default current-time policies
/// (path expiry and the ReaderAuth NameConstraints RFC 5280 policy) accept them without fixed-time
/// injection. The compliant hierarchy carries no NameConstraints, which RFC 5280 tolerates.
/// Individual `overrides` let a test flip exactly one attribute to drive a single negative boundary
/// while keeping every other check passing.
///
/// Shared certificate and header builders live in ``CoseSign1FixtureBuilder``; this type owns only
/// the ReaderAuth-specific concerns (detached payload, ReaderAuth EKU, DN naming, and the fixture
/// struct it returns).
enum DetachedReaderAuthFixtures {

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
        /// Build the leaf without the ReaderAuth EKU `1.0.18013.5.1.6` (drives
        /// `certificateProfileViolation`).
        var omitReaderAuthEKU = false
        /// Replace the signature with bytes that will not verify (drives `invalidSignature`).
        var tamperSignature = false
        /// The detached payload signed over and returned via the fixture's `detachedPayload`. Tests
        /// can pass different bytes to the verifier to prove the signature is bound to the exact
        /// caller-supplied payload.
        var detachedPayload = Data([0xDE, 0xAD, 0xBE, 0xEF])
    }

    static func make(_ overrides: Overrides = Overrides()) throws -> DetachedReaderAuthFixture {
        // Reader root CA (self-signed), valid across the present.
        let rootKey = P256.Signing.PrivateKey()
        let rootName = try CoseSign1FixtureBuilder.name("Test Reader Root")
        let root = try CoseSign1FixtureBuilder.caCertificate(
            subject: rootName, issuer: rootName, subjectKey: rootKey, issuerKey: rootKey
        )

        // An unrelated root, used only when a test wants an untrusted anchor.
        let wrongRootKey = P256.Signing.PrivateKey()
        let wrongRootName = try CoseSign1FixtureBuilder.name("Unrelated Root")
        let wrongRoot = try CoseSign1FixtureBuilder.caCertificate(
            subject: wrongRootName, issuer: wrongRootName, subjectKey: wrongRootKey, issuerKey: wrongRootKey
        )

        // ReaderAuth leaf signed by the root.
        let leafKey = P256.Signing.PrivateKey()
        let eku: [ASN1ObjectIdentifier] = overrides.omitReaderAuthEKU ? [] : [[1, 0, 18013, 5, 1, 6]]
        let leaf = try CoseSign1FixtureBuilder.endEntityCertificate(
            subject: try CoseSign1FixtureBuilder.name("Test ReaderAuth Leaf"),
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

        // Signature over the Sig_structure for the detached payload with the leaf key.
        let sigStructure = SigStructureBuilder.build(
            protectedHeaderBytes: protectedHeaderBytes,
            payload: overrides.detachedPayload
        )
        let realSignature = [UInt8](try leafKey.signature(for: sigStructure).rawRepresentation)
        let signatureBytes = overrides.tamperSignature
            ? [UInt8](repeating: 0x2B, count: 64)
            : realSignature

        // Detached COSE_Sign1: null payload field. The payload is supplied separately.
        let coseSign1 = cborCoseSign1(
            protectedHeader: [UInt8](protectedHeaderBytes),
            unprotectedHeader: unprotectedHeaderBytes,
            payload: .detached,
            signature: signatureBytes
        )

        return DetachedReaderAuthFixture(
            coseSign1Bytes: coseSign1,
            detachedPayload: overrides.detachedPayload,
            trustedRoot: overrides.useWrongTrustedRoot ? wrongRoot : root,
            leafDer: leafDer
        )
    }
}
