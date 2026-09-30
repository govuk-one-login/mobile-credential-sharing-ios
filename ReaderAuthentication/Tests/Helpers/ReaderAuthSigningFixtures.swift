@testable import ReaderAuthentication
import Crypto
import Foundation
import SwiftASN1
import X509

/// A distinctive detached payload used across the generator tests.
let readerAuthSamplePayload = Data([0xDE, 0xAD, 0xBE, 0xEF])

/// A leaf + intermediate chain, matching signing material, and the leaf public key for
/// round-trip verification.
struct ReaderAuthSigningFixture {
    let signingMaterial: ReaderAuthSigningMaterial
    let leafDER: Data
    let intermediateDER: Data
    let leafPublicKey: P256.Signing.PublicKey
}

/// Builds a valid, current-dated leaf + intermediate chain (both CA-signed, so neither is
/// self-signed) and the matching leaf key, returned as `ReaderAuthSigningMaterial`.
func makeReaderAuthSigningFixture() throws -> ReaderAuthSigningFixture {
    let caKey = P256.Signing.PrivateKey()
    let leafKey = P256.Signing.PrivateKey()
    let leaf = try makeReaderLeafCertificate(subjectKey: leafKey, caKey: caKey)
    let intermediate = try makeReaderLeafCertificate(subjectKey: P256.Signing.PrivateKey(), caKey: caKey)
    let leafDER = try derBytes(of: leaf)
    let intermediateDER = try derBytes(of: intermediate)
    return ReaderAuthSigningFixture(
        signingMaterial: ReaderAuthSigningMaterial(
            certificateChain: [leafDER, intermediateDER],
            leafPrivateKey: leafKey
        ),
        leafDER: leafDER,
        intermediateDER: intermediateDER,
        leafPublicKey: leafKey.publicKey
    )
}

// MARK: - Certificate builders

/// Validity window straddling the present so any current-time parse succeeds.
private let fixtureNotBefore = Date(timeIntervalSince1970: 1_780_000_000)
private let fixtureNotAfter = Date(timeIntervalSince1970: 1_820_000_000)

private func distinguishedName(_ commonName: String) throws -> DistinguishedName {
    try DistinguishedName { CountryName("GB"); CommonName(commonName) }
}

/// The DER encoding of a certificate (used for `x5chain` bytes and `x5t`).
func derBytes(of certificate: Certificate) throws -> Data {
    var serializer = DER.Serializer()
    try serializer.serialize(certificate)
    return Data(serializer.serializedBytes)
}

/// An end-entity leaf signed by a separate CA (issuer != subject, so not self-signed).
func makeReaderLeafCertificate(
    subjectKey: P256.Signing.PrivateKey,
    caKey: P256.Signing.PrivateKey
) throws -> Certificate {
    let caName = try distinguishedName("Test Reader CA")
    return try Certificate(
        version: .v3,
        serialNumber: Certificate.SerialNumber(),
        publicKey: Certificate.PublicKey(subjectKey.publicKey),
        notValidBefore: fixtureNotBefore,
        notValidAfter: fixtureNotAfter,
        issuer: caName,
        subject: try distinguishedName("Test Reader Leaf"),
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            KeyUsage(digitalSignature: true)
        },
        issuerPrivateKey: Certificate.PrivateKey(caKey)
    )
}
