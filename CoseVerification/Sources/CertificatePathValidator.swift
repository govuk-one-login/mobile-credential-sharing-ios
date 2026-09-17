import CryptoKit
import Foundation
import SwiftASN1
import X509

/// Validates a candidate certificate chain against a caller-provided trusted root.
///
/// The chain core — issuer↔subject linkage, per-link signature verification, authority/subject
/// key-identifier matching, and anchoring to the trusted root — is delegated to
/// swift-certificates' ``X509/Verifier``. Certificate **time validity** is enforced by an
/// ``X509/RFC5280Policy`` run inside that verifier: the verifier appends the matched trusted root
/// to the chain before applying policy, so the root's own `notBefore`/`notAfter` interval is
/// checked alongside the leaf and every intermediate.
///
/// A thin set of pre-passes enforces the rules that library policy does not express directly:
///
/// - the signature-algorithm allow-list (ECDSA-SHA-256/384) *and* the mandated
///   `tbsCertificate.signature == signatureAlgorithm` equality;
/// - the public-key allow-list (P-256/P-384).
///
/// The validation time used for the expiry check is supplied by `expiryPolicy`. Production uses
/// the default, which evaluates the current time *at the point of validation*. Tests inject a
/// fixed-time policy (via `@_spi(FixedExpiryValidationTime)`) so time-dependent behaviour is
/// deterministic without exposing a `Date` on the public surface.
///
/// Returns the validated path (leaf-first, excluding the root).
enum CertificatePathValidator {
    /// Supplies the ``X509/RFC5280Policy`` that performs the chain-wide expiry check.
    ///
    /// Defaults to a policy that evaluates the *current* time at the point of validation. The
    /// factory is invoked once per validation so the "current time" default is read at validation
    /// time, not at construction. Tests override this with a fixed-time policy.
    typealias ExpiryPolicyProvider = @Sendable () -> RFC5280Policy
    
    /// Critical extensions permitted on candidate certificates;
    /// this list only governs which critical OIDs are tolerated.
    private static let allowedCriticalExtensionOIDs: [ASN1ObjectIdentifier] = [
        .X509ExtensionID.subjectKeyIdentifier,
        .X509ExtensionID.keyUsage,
        .X509ExtensionID.subjectAlternativeName,
        .X509ExtensionID.basicConstraints,
        .X509ExtensionID.nameConstraints,
        [2, 5, 29, 31], // CRLDistributionPoints
        .X509ExtensionID.authorityKeyIdentifier,
        .X509ExtensionID.extendedKeyUsage
    ]

    /// Signature-algorithm OIDs permitted on candidate certificates (ECDSA-SHA-256/384).
    private static let allowedSignatureAlgorithmOIDs: Set<ASN1ObjectIdentifier> = [
        .ECDSASignatureAlgorithm.ecdsaWithSHA256OID,
        .ECDSASignatureAlgorithm.ecdsaWithSHA384OID
    ]

    /// Validates the leaf-first candidate chain against the trusted root.
    ///
    /// - Parameters:
    ///   - certificateChain: Leaf-first candidate DER (end-entity + intermediates, excluding root).
    ///   - trustedRootDer: The caller-provided trusted root.
    ///   - expiryPolicy: Supplies the RFC 5280 expiry policy run by the verifier. Defaults to a
    ///     current-time policy; tests inject a fixed-time policy.
    /// - Returns: The validated candidate path (leaf-first, excluding the root).
    /// - Throws: `unsupportedAlgorithm` for an algorithm/key violation;
    ///   `untrustedCertificate` for any time, linkage, anchoring, or extension-structure violation.
    static func validate(
        certificateChain: [Data],
        trustedRootDer: Data,
        expiryPolicy: ExpiryPolicyProvider = RFC5280Policy.init
    ) async throws -> [Data] {
        guard !certificateChain.isEmpty else { throw CoseVerificationFailure.untrustedCertificate }

        // The candidate chain must not contain the trusted root; anchoring uses it separately.
        guard !certificateChain.contains(trustedRootDer) else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        // Signature-algorithm allow-list + inner/outer equality, read directly from DER *before*
        // full parsing. A certificate signed with an algorithm swift-certificates does not model
        // (e.g. ECDSA-SHA1) fails `Certificate(derEncoded:)`; checking the OIDs first ensures such a
        // certificate is rejected distinctly as `unsupportedAlgorithm` rather than as a generic
        // parse failure.
        for der in certificateChain {
            try enforceSignatureAlgorithmOIDs(der: der)
        }

        // Any remaining structural DER problem is an untrusted certificate.
        let candidates = try certificateChain.map(parseCertificate)
        let root = try parseCertificate(trustedRootDer)

        // Public-key allow-list (curve + id-ecPublicKey), before anchoring, so a key violation
        // surfaces distinctly as `unsupportedAlgorithm`.
        for certificate in candidates {
            try enforcePublicKeyAllowList(certificate)
        }

        guard let leaf = candidates.first else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        try await evaluateTrust(
            leaf: leaf,
            intermediates: Array(candidates.dropFirst()),
            root: root,
            expiryPolicy: expiryPolicy
        )

        return certificateChain
    }

    // MARK: - swift-certificates chain core

    /// Anchors the candidate path to the trusted root and time-checks the whole chain.
    ///
    /// The ``X509/Verifier`` performs issuer↔subject linkage, per-link signature verification, and
    /// key-identifier matching while building the path to the root store. It appends the matched
    /// root to the chain before running policy, so the injected ``X509/RFC5280Policy`` checks the
    /// `notBefore`/`notAfter` interval of the leaf, every intermediate, *and* the trusted root.
    private static func evaluateTrust(
        leaf: Certificate,
        intermediates: [Certificate],
        root: Certificate,
        expiryPolicy: ExpiryPolicyProvider
    ) async throws {
        var verifier = Verifier(rootCertificates: CertificateStore([root])) {
            AllowListedCriticalExtensionsPolicy(handledExtensionOIDs: allowedCriticalExtensionOIDs)
            expiryPolicy()
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

    /// Enforces the signature-algorithm allow-list and the mandated inner/outer equality.
    ///
    /// The certificate is DER-parsed once. The outer `signatureAlgorithm` OID is taken from the
    /// parsed `Certificate` (no second DER walk); the inner `tbsCertificate.signature` OID is read
    /// from the DER because swift-certificates does not expose it. Both must be an allowed ECDSA
    /// OID and they must be equal (`tbsCertificate.signature` that differs from the outer
    /// `signatureAlgorithm` is rejected as `unsupportedAlgorithm`).
    private static func enforceSignatureAlgorithmOIDs(der: Data) throws {
        let node = try parse(der)
        let outer = try outerSignatureOID(node)
        let tbs = try tbsSignatureOID(node)

        guard allowedSignatureAlgorithmOIDs.contains(outer), outer == tbs else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }
    }

    /// Enforces the public-key allow-list. A P-256 or P-384 `Certificate.PublicKey` can only
    /// originate from an id-ecPublicKey SubjectPublicKeyInfo, so this also enforces the required
    /// public-key algorithm. Any other key type (RSA, P-521, Ed25519) is rejected.
    private static func enforcePublicKeyAllowList(_ certificate: Certificate) throws {
        let isSupportedCurve =
            P256.Signing.PublicKey(certificate.publicKey) != nil
            || P384.Signing.PublicKey(certificate.publicKey) != nil

        guard isSupportedCurve else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }
    }

    // MARK: - Minimal DER access for the inner signature-algorithm OID

    /// Reads `tbsCertificate.signature.algorithm` — the third field of `TBSCertificate`
    /// (`[0] version DEFAULT v1, serialNumber, signature, ...`). The optional `[0] EXPLICIT`
    /// version (context-specific tag 0) is skipped when present.
    private static func tbsSignatureOID(_ node: ASN1Node) throws -> ASN1ObjectIdentifier {
        let certificateFields = try constructedChildren(node)
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
        return try algorithmOID(tbsFields[1])
    }

    /// Reads the outer `Certificate.signatureAlgorithm.algorithm` — the second field of
    /// `Certificate` (`tbsCertificate, signatureAlgorithm, signatureValue`).
    private static func outerSignatureOID(_ node: ASN1Node) throws -> ASN1ObjectIdentifier {
        let certificateFields = try constructedChildren(node)
        guard certificateFields.count >= 2 else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        return try algorithmOID(certificateFields[1])
    }

    private static func parse(_ der: Data) throws -> ASN1Node {
        do {
            return try DER.parse(Array(der))
        } catch {
            // Malformed DER is an untrusted certificate, not an algorithm failure. Disallowed
            // algorithms (e.g. ECDSA-SHA1) still DER-parse successfully — they are rejected by the
            // OID allow-list in `enforceSignatureAlgorithmOIDs`, which is what surfaces
            // `unsupportedAlgorithm`. This keeps the truncated/trailing-bytes cases as
            // `untrustedCertificate`.
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
    private static func algorithmOID(_ algorithmIdentifier: ASN1Node) throws -> ASN1ObjectIdentifier {
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

fileprivate extension ASN1ObjectIdentifier {
    // Signature-algorithm OIDs. The allow-list and the tbsCertificate.signature == signatureAlgorithm
    // check are enforced directly from DER, because a certificate signed with an algorithm
    // swift-certificates does not model (e.g. ECDSA-SHA1) would otherwise fail parsing rather than
    // surfacing as a distinct `unsupportedAlgorithm`.
    /// OIDs that identify known ECDSA signature-algorithms.
    enum ECDSASignatureAlgorithm: Sendable {
        /// Identifies the ECDSA-SHA256 OID
        static let ecdsaWithSHA256OID: ASN1ObjectIdentifier = [1, 2, 840, 10045, 4, 3, 2]

        /// Identifies the ECDSA-SHA384 OID
        static let ecdsaWithSHA384OID: ASN1ObjectIdentifier = [1, 2, 840, 10045, 4, 3, 3]
    }
}
