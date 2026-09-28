@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
import X509

/// Shared certificate and COSE header builders for the certificate-backed fixture assemblers
/// (``AttachedIssuerAuthFixtures`` for IssuerAuth and ``DetachedReaderAuthFixtures`` for
/// ReaderAuth).
///
/// Both fixtures build the same kind of material — a self-signed CA, a `digitalSignature`
/// end-entity leaf, the leaf-first `x5chain` unprotected header, and the `x5t`-bearing protected
/// header — and differ only in the fixture struct they return, the end-entity EKU OID, and whether
/// the payload is attached or detached. This type owns the common builders so those role-specific
/// concerns stay in each fixture without copying the certificate and header encoding.
///
/// The default certificate validity windows straddle the present, so callers can rely on
/// current-time verification policies (path expiry, ReaderAuth NameConstraints) without fixed-time
/// injection.
enum CoseSign1FixtureBuilder {

    // MARK: - Validity windows

    /// CA validity window (2026-05 → 2027-09), straddling the present.
    static let caNotBefore = Date(timeIntervalSince1970: 1_780_000_000)
    static let caNotAfter = Date(timeIntervalSince1970: 1_820_000_000)

    /// End-entity validity window (2026-09-21 → 2027-05-11): ~231 days, within both the IssuerAuth
    /// 457-day and ReaderAuth 1187-day maxima, straddling the present.
    static let leafNotBefore = Date(timeIntervalSince1970: 1_790_000_000)
    static let leafNotAfter = Date(timeIntervalSince1970: 1_810_000_000)

    // MARK: - Certificate building

    /// A self-signed / CA certificate: critical BasicConstraints cA=true, KeyUsage
    /// keyCertSign+cRLSign, valid across the present.
    static func caCertificate(
        subject: DistinguishedName,
        issuer: DistinguishedName,
        subjectKey: P256.Signing.PrivateKey,
        issuerKey: P256.Signing.PrivateKey
    ) throws -> Certificate {
        try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(subjectKey.publicKey),
            notValidBefore: caNotBefore,
            notValidAfter: caNotAfter,
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

    /// An end-entity leaf: KeyUsage digitalSignature plus the supplied EKU OIDs (omitted when
    /// empty, to drive a `certificateProfileViolation`), valid across the present.
    static func endEntityCertificate(
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
        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(subjectKey.publicKey),
            notValidBefore: leafNotBefore,
            notValidAfter: leafNotAfter,
            issuer: issuer,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions(extensions),
            issuerPrivateKey: Certificate.PrivateKey(issuerKey)
        )
    }

    /// A `C=GB, CN=<commonName>` distinguished name.
    static func name(_ commonName: String) throws -> DistinguishedName {
        try DistinguishedName {
            CountryName("GB")
            CommonName(commonName)
        }
    }

    /// The DER encoding of a certificate (used for `x5chain` bytes, `x5t`, and substitution
    /// assertions).
    static func der(of certificate: Certificate) throws -> Data {
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        return Data(serializer.serializedBytes)
    }

    // MARK: - Header encoding

    /// Builds the protected-header bytes: a CBOR map of `{1: alg}` optionally plus
    /// `{34: [-16, sha256(leaf)]}` (`x5t`). When `base` is not the canonical ES256 header it is
    /// passed through unchanged so negative alg vectors keep their exact bytes.
    static func protectedHeader(base: Data, leafDer: Data, includeX5t: Bool) throws -> Data {
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
    static func unprotectedHeaderWithX5Chain(_ chain: [Data]) -> [UInt8] {
        var bytes: [UInt8] = [0xA1]          // map(1)
        bytes += [0x18, 0x21]                // key 33 (x5chain)
        bytes += [UInt8(0x80 + chain.count)] // array(count) — count is small in tests
        for der in chain {
            bytes += cborByteString([UInt8](der))
        }
        return bytes
    }
}
