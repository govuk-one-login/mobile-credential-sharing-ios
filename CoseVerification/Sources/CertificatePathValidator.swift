import Foundation
import CryptoKit
import X509
import SwiftASN1

/// Validates a candidate certificate chain against a caller-provided trusted root.
///
/// The chain core — issuer↔subject linkage, per-link signature verification, authority/subject
/// key-identifier matching, and anchoring to the trusted root — is delegated to
/// swift-certificates' ``X509/Verifier``. The verifier builds a path from the leaf to the trusted
/// root store, checking each link's signature and issuer as it goes, and only reports success when
/// a chain reaches the anchor. A thin set of pre-passes enforces the product rules that library
/// policy does not express directly:
///
/// - candidate time validity (`notBefore <= now <= notAfter`),
/// - the signature-algorithm / public-key allow-list (ECDSA-SHA-256/384 with P-256/P-384),
/// - the critical-extension OID allow-list and the unique-extension-OID rule.
///
/// The trusted root is trusted by default: its own validity period is *not* checked. All time
/// validity is enforced by the candidate pre-pass against `now`; the verifier policy performs no
/// expiry check (this deliberately avoids `RFC5280Policy`, whose expiry check would reject an
/// expired-but-trusted anchor, and avoids any `@_spi` API).
///
/// Returns the validated path (leaf-first, excluding the root).
enum CertificatePathValidator {

    // Allowed outer signature algorithms.
    private static let allowedSignatureAlgorithms: Set<Certificate.SignatureAlgorithm> = [
        .ecdsaWithSHA256,
        .ecdsaWithSHA384
    ]

    // Signature-algorithm OIDs, for the tbsCertificate.signature == signatureAlgorithm check, which
    // the public swift-certificates API does not expose.
    private static let ecdsaWithSha256Oid: ASN1ObjectIdentifier = [1, 2, 840, 10045, 4, 3, 2]
    private static let ecdsaWithSha384Oid: ASN1ObjectIdentifier = [1, 2, 840, 10045, 4, 3, 3]

    /// Critical extensions permitted here. Presence/value rules belong to profile validation.
    private static let allowedCriticalExtensionOids: Set<ASN1ObjectIdentifier> = [
        [2, 5, 29, 14], // SubjectKeyIdentifier
        [2, 5, 29, 15], // KeyUsage
        [2, 5, 29, 17], // SubjectAlternativeName
        [2, 5, 29, 19], // BasicConstraints
        [2, 5, 29, 30], // NameConstraints
        [2, 5, 29, 31], // CRLDistributionPoints
        [2, 5, 29, 35], // AuthorityKeyIdentifier
        [2, 5, 29, 37]  // ExtendedKeyUsage
    ]

    /// Validates the leaf-first candidate chain against the trusted root.
    ///
    /// - Parameters:
    ///   - certificateChain: Leaf-first candidate DER. Holds the end-entity certificate and every
    ///     intermediate up to (but not including) the root.
    ///   - trustedRootDer: The caller-provided trusted root. Trusted by default; its own validity
    ///     period is not checked.
    ///   - now: Reference instant for candidate time-validity checks. Defaults to now.
    /// - Returns: The validated candidate path (leaf-first, excluding the root).
    /// - Throws: `unsupportedAlgorithm` for an algorithm/key violation;
    ///   `untrustedCertificate` for any time, linkage, anchoring, or extension-structure violation.
    static func validate(
        certificateChain: [Data],
        trustedRootDer: Data,
        now: Date = Date()
    ) async throws -> [Data] {
        guard !certificateChain.isEmpty else { throw CoseVerificationFailure.untrustedCertificate }

        // The candidate chain must not contain the trusted root; anchoring uses it separately.
        guard !certificateChain.contains(trustedRootDer) else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        // Any structural DER problem is an untrusted certificate.
        let candidates = try certificateChain.map(parseCertificate)
        let root = try parseCertificate(trustedRootDer)

        // Candidate time validity (the root's own validity is not checked).
        for certificate in candidates {
            guard certificate.notValidBefore <= now, now <= certificate.notValidAfter else {
                throw CoseVerificationFailure.untrustedCertificate
            }
        }

        // Algorithm/key allow-list, before anchoring, so a violation surfaces distinctly.
        for (certificate, der) in zip(candidates, certificateChain) {
            try enforceAlgorithmAllowList(certificate, der: der)
        }

        // Extension structure (unique OIDs; critical OIDs restricted to the allow-list).
        for certificate in candidates {
            try enforceExtensionStructure(certificate)
        }

        guard let leaf = candidates.first else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        try await evaluateTrust(
            leaf: leaf,
            intermediates: Array(candidates.dropFirst()),
            root: root
        )

        return certificateChain
    }

    // MARK: - swift-certificates chain core

    /// Anchors the candidate path to the trusted root. The ``X509/Verifier`` performs issuer↔subject
    /// linkage, per-link signature verification, and key-identifier matching while building the path
    /// to the root store, so a minimal policy is sufficient for those checks. Time validity is not
    /// re-checked here (handled by the candidate pre-pass; the root is intentionally exempt).
    private static func evaluateTrust(
        leaf: Certificate,
        intermediates: [Certificate],
        root: Certificate
    ) async throws {
        var verifier = Verifier(rootCertificates: CertificateStore([root])) {
            AllowListedCriticalExtensionsPolicy(handledExtensionOids: Array(allowedCriticalExtensionOids))
        }

        let result = await verifier.validate(
            leaf: leaf,
            intermediates: CertificateStore(intermediates)
        )

        guard case .validCertificate = result else {
            throw CoseVerificationFailure.untrustedCertificate
        }
    }

    private static func parseCertificate(_ der: Data) throws -> Certificate {
        do {
            return try Certificate(derEncoded: Array(der))
        } catch {
            throw CoseVerificationFailure.untrustedCertificate
        }
    }

    // MARK: - Custom allow-list checks

    private static func enforceAlgorithmAllowList(_ certificate: Certificate, der: Data) throws {
        // Outer signatureAlgorithm and the public-key curve. A P-256 or P-384 `Certificate.PublicKey`
        // can only originate from an id-ecPublicKey SubjectPublicKeyInfo, so this also enforces the
        // required public-key algorithm.
        let isSupportedCurve =
            P256.Signing.PublicKey(certificate.publicKey) != nil
            || P384.Signing.PublicKey(certificate.publicKey) != nil

        guard allowedSignatureAlgorithms.contains(certificate.signatureAlgorithm), isSupportedCurve else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        // tbsCertificate.signature must equal the outer signatureAlgorithm. swift-certificates does
        // not expose the inner algorithm, so read its OID with a minimal DER decode.
        guard try tbsSignatureOid(der: der) == outerSignatureOid(der: der) else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }
    }

    private static func enforceExtensionStructure(_ certificate: Certificate) throws {
        var encounteredExtensionOids = Set<ASN1ObjectIdentifier>()
        for ext in certificate.extensions {
            guard encounteredExtensionOids.insert(ext.oid).inserted else {
                throw CoseVerificationFailure.untrustedCertificate
            }
            if ext.critical && !allowedCriticalExtensionOids.contains(ext.oid) {
                throw CoseVerificationFailure.untrustedCertificate
            }
        }
    }

    // MARK: - Minimal DER access for the inner/outer signature-algorithm comparison

    /// Reads `tbsCertificate.signature.algorithm` — the third field of `TBSCertificate`
    /// (`[0] version DEFAULT v1, serialNumber, signature, ...`). The optional `[0] EXPLICIT`
    /// version (context-specific tag 0) is skipped when present.
    private static func tbsSignatureOid(der: Data) throws -> ASN1ObjectIdentifier {
        let certificate = try parse(der)
        let certificateFields = try constructedChildren(certificate)
        guard let tbs = certificateFields.first else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        var tbsFields = try constructedChildren(tbs)
        let versionTag = ASN1Identifier(tagWithNumber: 0, tagClass: .contextSpecific)
        if tbsFields.first?.identifier == versionTag {
            tbsFields.removeFirst() // [0] EXPLICIT version
        }
        // Remaining: serialNumber, signature (AlgorithmIdentifier), ...
        guard tbsFields.count >= 2 else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        return try algorithmOid(tbsFields[1])
    }

    /// Reads the outer `Certificate.signatureAlgorithm.algorithm` — the second field of
    /// `Certificate` (`tbsCertificate, signatureAlgorithm, signatureValue`).
    private static func outerSignatureOid(der: Data) throws -> ASN1ObjectIdentifier {
        let certificate = try parse(der)
        let certificateFields = try constructedChildren(certificate)
        guard certificateFields.count >= 2 else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        return try algorithmOid(certificateFields[1])
    }

    private static func parse(_ der: Data) throws -> ASN1Node {
        do {
            return try DER.parse(Array(der))
        } catch {
            throw CoseVerificationFailure.untrustedCertificate
        }
    }

    /// Returns the child nodes of a constructed (SEQUENCE/SET) node.
    private static func constructedChildren(_ node: ASN1Node) throws -> [ASN1Node] {
        guard case .constructed(let children) = node.content else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        return Array(children)
    }

    /// Reads the `algorithm` OID from an `AlgorithmIdentifier ::= SEQUENCE { algorithm, ... }`.
    private static func algorithmOid(_ algorithmIdentifier: ASN1Node) throws -> ASN1ObjectIdentifier {
        let fields = try constructedChildren(algorithmIdentifier)
        guard let algorithm = fields.first else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        do {
            return try ASN1ObjectIdentifier(derEncoded: algorithm)
        } catch {
            throw CoseVerificationFailure.untrustedCertificate
        }
    }
}
