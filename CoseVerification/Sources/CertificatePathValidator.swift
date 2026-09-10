import Foundation
import Security

/// Validates a candidate certificate chain against a caller-provided trusted root.
///
/// `SecTrust` owns the chain core (issuer↔subject linkage, per-link signature, anchoring). A thin
/// custom pass enforces the product rules the platform does not: candidate time validity, the
/// signature-algorithm / public-key allow-list (ECDSA-SHA-256/384 with P-256/P-384), and the
/// critical-extension OID allow-list.
///
/// Those allow-list fields come from a minimal DER decode (``X509Certificate``) because iOS does
/// not expose parsed certificate fields (`SecCertificateCopyValues` is macOS-only). The decode
/// reads fields only; `SecTrust` performs all signature and linkage checks.
///
/// Returns the validated path (leaf-first, excluding the root). Profile rules and revocation are
/// out of scope.
enum CertificatePathValidator {

    // Allowed signature algorithms.
    private static let ecdsaWithSha256 = "1.2.840.10045.4.3.2"
    private static let ecdsaWithSha384 = "1.2.840.10045.4.3.3"
    private static let allowedSignatureAlgorithms: Set<String> = [ecdsaWithSha256, ecdsaWithSha384]

    // Allowed public key algorithm and curves.
    private static let idEcPublicKey = "1.2.840.10045.2.1"
    private static let curveP256 = "1.2.840.10045.3.1.7"
    private static let curveP384 = "1.3.132.0.34"
    private static let allowedCurves: Set<String> = [curveP256, curveP384]

    /// Critical extensions permitted here. Presence/value rules belong to profile validation.
    private static let allowedCriticalExtensionOids: Set<String> = [
        "2.5.29.14", // SubjectKeyIdentifier
        "2.5.29.15", // KeyUsage
        "2.5.29.17", // SubjectAlternativeName
        "2.5.29.19", // BasicConstraints
        "2.5.29.30", // NameConstraints
        "2.5.29.31", // CRLDistributionPoints
        "2.5.29.35", // AuthorityKeyIdentifier
        "2.5.29.37"  // ExtendedKeyUsage
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
    ) throws -> [Data] {
        guard !certificateChain.isEmpty else { throw CoseVerificationFailure.untrustedCertificate }

        // The candidate chain must not contain the trusted root; anchoring uses it separately.
        guard !certificateChain.contains(trustedRootDer) else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        // X509Certificate enforces strict DER (one Certificate, no trailing bytes).
        let parsed = try certificateChain.map { try X509Certificate(der: $0) }

        // Enforced here (not via SecTrust) because SecTrust verifies at the leaf's notBefore below,
        // which exempts the root's own expiry.
        for certificate in parsed {
            guard certificate.notBefore <= now, now <= certificate.notAfter else {
                throw CoseVerificationFailure.untrustedCertificate
            }
        }

        // Before SecTrust, so an algorithm/key violation surfaces distinctly.
        for certificate in parsed {
            try enforceAlgorithmAllowList(certificate)
        }

        for certificate in parsed {
            try enforceExtensionStructure(certificate)
        }

        // Verify at the leaf's notBefore — a point where every cert in a well-formed chain
        // (including the root) was valid — so the anchor's expiry never rejects a valid path.
        try evaluateTrust(
            certificateChain: certificateChain,
            trustedRootDer: trustedRootDer,
            verifyDate: parsed[0].notBefore
        )

        return certificateChain
    }

    // MARK: - SecTrust chain core

    private static func evaluateTrust(
        certificateChain: [Data],
        trustedRootDer: Data,
        verifyDate: Date
    ) throws {
        let candidates = try certificateChain.map { try makeCertificate($0) }
        let root = try makeCertificate(trustedRootDer)

        var optionalTrust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let status = SecTrustCreateWithCertificates(candidates as CFArray, policy, &optionalTrust)

        guard status == errSecSuccess, let trust = optionalTrust else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        guard SecTrustSetAnchorCertificates(trust, [root] as CFArray) == errSecSuccess,
              SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,
              SecTrustSetVerifyDate(trust, verifyDate as CFDate) == errSecSuccess else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        // Revocation is out of scope; SecTrust performs none by default.
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            throw CoseVerificationFailure.untrustedCertificate
        }
    }

    private static func makeCertificate(_ der: Data) throws -> SecCertificate {
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        return certificate
    }

    // MARK: - Custom allow-list checks

    private static func enforceAlgorithmAllowList(_ certificate: X509Certificate) throws {
        guard allowedSignatureAlgorithms.contains(certificate.signatureAlgorithmOid),
              certificate.tbsSignatureAlgorithmOid == certificate.signatureAlgorithmOid,
              certificate.subjectPublicKeyAlgorithmOid == idEcPublicKey,
              let curve = certificate.subjectPublicKeyCurveOid, allowedCurves.contains(curve) else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }
    }

    private static func enforceExtensionStructure(_ certificate: X509Certificate) throws {
        var seenOids = Set<String>()
        for ext in certificate.extensions {
            guard seenOids.insert(ext.oid).inserted else {
                throw CoseVerificationFailure.untrustedCertificate
            }
            if ext.critical && !allowedCriticalExtensionOids.contains(ext.oid) {
                throw CoseVerificationFailure.untrustedCertificate
            }
        }
    }
}
