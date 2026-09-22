@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
@_spi(FixedExpiryValidationTime) import X509

/// Builds real, signed DER certificate hierarchies for ``CertificateProfileValidator`` (C6) tests.
///
/// Certificates are generated in-process with the X509 library so each test can vary exactly one
/// profile attribute (version, serial, subject, BasicConstraints, KeyUsage, EKU, validity span)
/// without external OpenSSL fixtures. A hierarchy is `root → [intermediate] → leaf`, linked by
/// issuer/subject DN. The builder returns a ``CertificatePathValidator/ValidatedPath`` (the C6
/// `path`, leaf-first and excluding the root, together with the parsed root), matching
/// ``CertificateProfileValidator/validate(validatedPath:role:rfc5280Policy:)``.
enum ProfileCertificateFactory {

    // MARK: - Profile knobs

    /// Mutable description of one certificate's profile, so tests can flip a single attribute.
    struct CertificateSpec {
        var version: Certificate.Version = .v3
        var commonName: String? = "Test Certificate"
        var countryName: String? = "GB"
        var notValidBefore = Date(timeIntervalSince1970: 1_780_000_000) // 2026-05
        var notValidAfter = Date(timeIntervalSince1970: 1_820_000_000)  // 2027-09
        var keyUsage: KeyUsage?
        var basicConstraints: (constraints: BasicConstraints, critical: Bool)?
        var extendedKeyUsageOIDs: [ASN1ObjectIdentifier] = []
        var nameConstraints: (constraints: NameConstraints, critical: Bool)?
    }

    // MARK: - Fixed validation time

    /// A validation instant inside every generated certificate's default window.
    static let validationTime = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15

    /// A fixed-time RFC 5280 policy provider for deterministic ReaderAuth NameConstraints checks.
    static func rfc5280(at time: Date = validationTime) -> CertificateProfileValidator.RFC5280PolicyProvider {
        { RFC5280Policy(fixedExpiryValidationTime: time) }
    }

    // MARK: - Compliant specs per role

    /// A fully profile-compliant IssuerAuth hierarchy. Callers mutate the returned specs and rebuild
    /// via ``build(root:intermediate:leaf:)`` to produce negative cases.
    static func issuerAuthSpecs() -> (root: CertificateSpec, intermediate: CertificateSpec, leaf: CertificateSpec) {
        (root: caSpec(commonName: "Test Root"),
         intermediate: caSpec(commonName: "Test Intermediate"),
         leaf: endEntitySpec(commonName: "Test IssuerAuth Leaf", eku: [1, 0, 18013, 5, 1, 2]))
    }

    /// A fully profile-compliant ReaderAuth hierarchy.
    static func readerAuthSpecs() -> (root: CertificateSpec, intermediate: CertificateSpec, leaf: CertificateSpec) {
        (root: caSpec(commonName: "Test Root"),
         intermediate: caSpec(commonName: "Test Intermediate"),
         leaf: endEntitySpec(commonName: "Test ReaderAuth Leaf", eku: [1, 0, 18013, 5, 1, 6]))
    }

    /// A default compliant CA (root or intermediate) spec: critical BasicConstraints cA=true,
    /// KeyUsage exactly keyCertSign + cRLSign.
    static func caSpec(commonName: String) -> CertificateSpec {
        var spec = CertificateSpec()
        spec.commonName = commonName
        spec.keyUsage = KeyUsage(keyCertSign: true, cRLSign: true)
        spec.basicConstraints = (.isCertificateAuthority(maxPathLength: nil), true)
        return spec
    }

    /// A default compliant end-entity spec: no BasicConstraints, KeyUsage exactly digitalSignature,
    /// the supplied EKU OID, validity span ~231 days (within both role limits).
    static func endEntitySpec(commonName: String, eku: ASN1ObjectIdentifier) -> CertificateSpec {
        var spec = CertificateSpec()
        spec.commonName = commonName
        spec.keyUsage = KeyUsage(digitalSignature: true)
        spec.extendedKeyUsageOIDs = [eku]
        spec.notValidBefore = Date(timeIntervalSince1970: 1_790_000_000)
        spec.notValidAfter = Date(timeIntervalSince1970: 1_810_000_000) // ~231 days later
        return spec
    }

    // MARK: - Building

    /// Builds `root → intermediate → leaf`, returning a ``CertificatePathValidator/ValidatedPath``:
    /// the C6 path (leaf-first, excluding root) and the parsed root. When `intermediate` is nil a
    /// two-cert hierarchy `root → leaf` is built.
    static func build(
        root rootSpec: CertificateSpec,
        intermediate intermediateSpec: CertificateSpec?,
        leaf leafSpec: CertificateSpec
    ) throws -> CertificatePathValidator.ValidatedPath {
        let rootKey = P256.Signing.PrivateKey()
        let rootName = try distinguishedName(rootSpec)
        let rootCert = try certificate(
            rootSpec,
            subject: rootName,
            issuer: rootName,
            subjectKey: Certificate.PublicKey(rootKey.publicKey),
            issuerKey: Certificate.PrivateKey(rootKey)
        )

        let leafKey = P256.Signing.PrivateKey()

        if let intermediateSpec {
            let intKey = P256.Signing.PrivateKey()
            let intName = try distinguishedName(intermediateSpec)
            let intCert = try certificate(
                intermediateSpec,
                subject: intName,
                issuer: rootName,
                subjectKey: Certificate.PublicKey(intKey.publicKey),
                issuerKey: Certificate.PrivateKey(rootKey)
            )
            let leafCert = try certificate(
                leafSpec,
                subject: try distinguishedName(leafSpec),
                issuer: intName,
                subjectKey: Certificate.PublicKey(leafKey.publicKey),
                issuerKey: Certificate.PrivateKey(intKey)
            )
            return CertificatePathValidator.ValidatedPath(root: rootCert, path: [leafCert, intCert])
        } else {
            let leafCert = try certificate(
                leafSpec,
                subject: try distinguishedName(leafSpec),
                issuer: rootName,
                subjectKey: Certificate.PublicKey(leafKey.publicKey),
                issuerKey: Certificate.PrivateKey(rootKey)
            )
            return CertificatePathValidator.ValidatedPath(root: rootCert, path: [leafCert])
        }
    }

    // MARK: - Internals

    private static func certificate(
        _ spec: CertificateSpec,
        subject: DistinguishedName,
        issuer: DistinguishedName,
        subjectKey: Certificate.PublicKey,
        issuerKey: Certificate.PrivateKey
    ) throws -> Certificate {
        var extensions: [Certificate.Extension] = []

        if let keyUsage = spec.keyUsage {
            extensions.append(try .init(keyUsage, critical: false))
        }
        if let basicConstraints = spec.basicConstraints {
            extensions.append(try .init(basicConstraints.constraints, critical: basicConstraints.critical))
        }
        if !spec.extendedKeyUsageOIDs.isEmpty {
            let eku = try ExtendedKeyUsage(spec.extendedKeyUsageOIDs.map { ExtendedKeyUsage.Usage(oid: $0) })
            extensions.append(try .init(eku, critical: false))
        }
        if let nameConstraints = spec.nameConstraints {
            extensions.append(try .init(nameConstraints.constraints, critical: nameConstraints.critical))
        }

        return try Certificate(
            version: spec.version,
            serialNumber: Certificate.SerialNumber(),
            publicKey: subjectKey,
            notValidBefore: spec.notValidBefore,
            notValidAfter: spec.notValidAfter,
            issuer: issuer,
            subject: subject,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions(extensions),
            issuerPrivateKey: issuerKey
        )
    }

    private static func distinguishedName(_ spec: CertificateSpec) throws -> DistinguishedName {
        var attributes: [RelativeDistinguishedName.Attribute] = []
        if let countryName = spec.countryName {
            attributes.append(try .init(type: .RDNAttributeType.countryName, printableString: countryName))
        }
        if let commonName = spec.commonName {
            attributes.append(.init(type: .RDNAttributeType.commonName, utf8String: commonName))
        }
        return try DistinguishedName(attributes)
    }
}
