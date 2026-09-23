@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
import X509

/// A fully-encoded attached IssuerAuth COSE_Sign1 plus the trusted root that anchors it.
///
/// Produced by ``makeAttachedIssuerAuth(_:)``. The COSE_Sign1 embeds the leaf-first `x5chain`
/// (unprotected) and the leaf `x5t` (protected), and its signature is computed over the
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
        let rootName = try name("Test Issuer Root")
        let root = try caCertificate(subject: rootName, issuer: rootName, subjectKey: rootKey, issuerKey: rootKey)

        // An unrelated root, used only when a test wants an untrusted anchor.
        let wrongRootKey = P256.Signing.PrivateKey()
        let wrongRootName = try name("Unrelated Root")
        let wrongRoot = try caCertificate(
            subject: wrongRootName, issuer: wrongRootName, subjectKey: wrongRootKey, issuerKey: wrongRootKey
        )

        // IssuerAuth leaf signed by the root.
        let leafKey = P256.Signing.PrivateKey()
        let eku: [ASN1ObjectIdentifier] = overrides.omitIssuerAuthEKU ? [] : [[1, 0, 18013, 5, 1, 2]]
        let leaf = try endEntityCertificate(
            subject: try name("Test IssuerAuth Leaf"),
            issuer: rootName,
            subjectKey: leafKey,
            issuerKey: rootKey,
            eku: eku
        )
        let leafDer = try der(of: leaf)

        // Protected header: alg (and, on the success path, x5t binding the leaf).
        let protectedHeaderBytes = try protectedHeader(
            base: overrides.protectedHeader,
            leafDer: leafDer,
            includeX5t: overrides.protectedHeader == es256ProtectedHeader
        )

        // Unprotected header: leaf-first x5chain (unless the test omits it).
        let unprotectedHeaderBytes = overrides.omitX5Chain
            ? [UInt8](arrayLiteral: 0xA0)
            : unprotectedHeaderWithX5Chain([leafDer])

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

    // MARK: - Header encoding

    /// Builds the protected-header bytes: a CBOR map of `{1: alg}` optionally plus
    /// `{34: [-16, sha256(leaf)]}` (`x5t`). When `base` is not the canonical ES256 header we pass it
    /// through unchanged so negative alg vectors keep their exact bytes.
    private static func protectedHeader(base: Data, leafDer: Data, includeX5t: Bool) throws -> Data {
        guard includeX5t else { return base }

        // {1: -7, 34: [-16, h'<32-byte digest>']}
        let digest = [UInt8](SHA256.hash(data: leafDer))
        var map: [UInt8] = [0xA2]            // map(2)
        map += [0x01, 0x26]                  // 1: -7 (ES256)
        map += [0x18, 0x22]                  // key 34 (x5t)
        map += [0x82]                        // array(2)
        map += [0x2F]                        // -16 (SHA-256), canonical short form
        map += cborByteString(digest)        // h'digest'
        return Data(map)
    }

    /// Encodes an unprotected header map `{33: [der, ...]}` (leaf-first x5chain).
    private static func unprotectedHeaderWithX5Chain(_ chain: [Data]) -> [UInt8] {
        var bytes: [UInt8] = [0xA1]          // map(1)
        bytes += [0x18, 0x21]                // key 33 (x5chain)
        bytes += [UInt8(0x80 + chain.count)] // array(count) — count is small in tests
        for der in chain {
            bytes += cborByteString([UInt8](der))
        }
        return bytes
    }

    // MARK: - Certificate building

    private static let notBefore = Date(timeIntervalSince1970: 1_780_000_000) // 2026-05
    private static let notAfter = Date(timeIntervalSince1970: 1_820_000_000)   // 2027-09

    private static func caCertificate(
        subject: DistinguishedName,
        issuer: DistinguishedName,
        subjectKey: P256.Signing.PrivateKey,
        issuerKey: P256.Signing.PrivateKey
    ) throws -> Certificate {
        try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(subjectKey.publicKey),
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: issuer,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions {
                Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
                KeyUsage(keyCertSign: true, cRLSign: true)
            },
            issuerPrivateKey: Certificate.PrivateKey(issuerKey)
        )
    }

    private static func endEntityCertificate(
        subject: DistinguishedName,
        issuer: DistinguishedName,
        subjectKey: P256.Signing.PrivateKey,
        issuerKey: P256.Signing.PrivateKey,
        eku: [ASN1ObjectIdentifier]
    ) throws -> Certificate {
        var extensions: [Certificate.Extension] = []
        extensions.append(try .init(KeyUsage(digitalSignature: true), critical: false))
        if !eku.isEmpty {
            let usage = try ExtendedKeyUsage(eku.map { ExtendedKeyUsage.Usage(oid: $0) })
            extensions.append(try .init(usage, critical: false))
        }
        // ~231-day validity, within the IssuerAuth 457-day maximum, straddling the present.
        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(subjectKey.publicKey),
            notValidBefore: Date(timeIntervalSince1970: 1_790_000_000), // 2026-09-21
            notValidAfter: Date(timeIntervalSince1970: 1_810_000_000),  // 2027-05-11
            issuer: issuer,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions(extensions),
            issuerPrivateKey: Certificate.PrivateKey(issuerKey)
        )
    }

    private static func name(_ commonName: String) throws -> DistinguishedName {
        try DistinguishedName {
            CountryName("GB")
            CommonName(commonName)
        }
    }

    private static func der(of certificate: Certificate) throws -> Data {
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        return Data(serializer.serializedBytes)
    }
}
