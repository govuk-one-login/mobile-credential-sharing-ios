import Foundation
import SwiftASN1
import X509

/// Validates the X.509 *profile* of a trusted certificate path (C6) and returns the approved
/// end-entity public key.
///
/// C5 (``CertificatePathValidator``) has already established that the path is current, correctly
/// linked, cryptographically valid, and anchored by the caller-provided trusted root. C6 enforces
/// the ISO 18013-5 / GDS certificate **profile** by composing a set of small ``X509/VerifierPolicy``
/// values and running them through the library ``X509/Verifier``:
///
/// - **Common** rules — applied to the end-entity, every intermediate, *and* the trusted root
///   (the verifier appends the matched root to the chain before policy evaluation):
///   ``CertificateVersionPolicy``, ``SerialNumberPresentPolicy``, ``SubjectProfilePolicy``.
/// - **Intermediate** rules — applied to intermediates only (leaf and root excluded, see
///   ``UnverifiedCertificateChain/intermediates``): ``IntermediateBasicConstraintsPolicy``,
///   ``IntermediateKeyUsagePolicy``.
/// - **End-entity** rules — applied to the leaf only: ``EndEntityBasicConstraintsPolicy``,
///   ``EndEntityKeyUsagePolicy``, ``EndEntityExtendedKeyUsagePolicy``,
///   ``EndEntityValidityDurationPolicy``.
/// - **ReaderAuth NameConstraints** — ``PrefixNameConstraintsPolicy`` (RFC 5280 directoryName
///   prefix matching, implemented locally on upstream swift-certificates) is composed for the
///   ReaderAuth role only.
///
/// On success the approved end-entity public key is returned for signature verification (C3). Any
/// profile violation throws ``CoseVerificationFailure/certificateProfileViolation(reason:)`` whose
/// `reason` names the failed rule; callers do not branch on the text.
enum CertificateProfileValidator {

    /// Selects the end-entity rules and whether NameConstraints is enforced.
    enum Role {
        /// IssuerAuth (certificate-backed attached). EKU `1.0.18013.5.1.2`; validity <= 457 days.
        case issuerAuth
        /// ReaderAuth (certificate-backed detached). EKU `1.0.18013.5.1.6`; validity <= 1187 days;
        /// the path must additionally pass NameConstraints validation.
        case readerAuth

        fileprivate var requiredEndEntityEKU: ASN1ObjectIdentifier {
            switch self {
            case .issuerAuth: return .MDLEKU.issuerAuth
            case .readerAuth: return .MDLEKU.readerAuth
            }
        }

        fileprivate var maxEndEntityValidityDays: Int {
            switch self {
            case .issuerAuth: return 457
            case .readerAuth: return 1187
            }
        }

        fileprivate var enforcesNameConstraints: Bool {
            switch self {
            case .issuerAuth: return false
            case .readerAuth: return true
            }
        }
    }

    /// The diagnostic reasons this validator's own profile policies can emit. Used to distinguish an
    /// in-module profile failure from a ``PrefixNameConstraintsPolicy`` NameConstraints failure when
    /// mapping the verifier's result.
    private static let ownProfileReasons: Set<String> = [
        CertificateProfileReason.version,
        CertificateProfileReason.serialNumber,
        CertificateProfileReason.subject,
        CertificateProfileReason.basicConstraints,
        CertificateProfileReason.keyUsage,
        CertificateProfileReason.extendedKeyUsage,
        CertificateProfileReason.validityPeriod
    ]

    /// Critical extensions tolerated by the profile verifier. Mirrors the C5 allow-list.
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

    /// Enforces the certificate profile on the trusted path and returns the approved end-entity key.
    ///
    /// - Parameters:
    ///   - validatedPath: The result from C5 (``CertificatePathValidator/ValidatedPath``): the
    ///     leaf-first path excluding the root, plus the parsed trusted root used to anchor the
    ///     profile verifier. Both certificates are already parsed, so no DER re-parsing occurs here.
    ///   - role: Selects the IssuerAuth or ReaderAuth end-entity rules.
    /// - Returns: The approved end-entity ``X509/Certificate/PublicKey`` for signature verification.
    /// - Throws: ``CoseVerificationFailure/certificateProfileViolation(reason:)`` for any profile
    ///   violation; ``CoseVerificationFailure/untrustedCertificate`` if the path is structurally
    ///   unusable (empty).
    static func validate(
        validatedPath: CertificatePathValidator.ValidatedPath,
        role: Role
    ) async throws -> Certificate.PublicKey {
        guard let leaf = validatedPath.path.first else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        let intermediates = validatedPath.path.dropFirst()

        var verifier = Verifier(rootCertificates: CertificateStore([validatedPath.root])) {
            profilePolicySet(role: role)
        }

        let result = await verifier.validate(
            leaf: leaf,
            intermediates: CertificateStore(intermediates)
        )

        switch result {
        case .validCertificate:
            return leaf.publicKey
        case .couldNotValidate(let failures):
            throw profileViolation(from: failures)
        }
    }

    /// Composes the role-appropriate profile policy set.
    @PolicyBuilder
    private static func profilePolicySet(
        role: Role
    ) -> some VerifierPolicy {
        // Tolerate the same critical extensions C5 allows, so a path that passed C5 is not rejected
        // here for an unrelated critical extension.
        AllowListedCriticalExtensionsPolicy(handledExtensionOIDs: allowedCriticalExtensionOIDs)

        // Common rules (leaf + intermediates + root).
        CertificateVersionPolicy()
        SerialNumberPresentPolicy()
        SubjectProfilePolicy()

        // Intermediate-only rules.
        IntermediateBasicConstraintsPolicy()
        IntermediateKeyUsagePolicy()

        // End-entity rules.
        EndEntityBasicConstraintsPolicy()
        EndEntityKeyUsagePolicy()
        EndEntityExtendedKeyUsagePolicy(requiredOID: role.requiredEndEntityEKU)
        EndEntityValidityDurationPolicy(maximumValidityDays: role.maxEndEntityValidityDays)

        // ReaderAuth additionally enforces NameConstraints via the local prefix-matching policy.
        if role.enforcesNameConstraints {
            PrefixNameConstraintsPolicy()
        }
    }

    /// Maps the verifier's policy failures to a ``CoseVerificationFailure``.
    ///
    /// A failure whose reason is one of this validator's own profile reasons is passed straight
    /// through. Any other reason can only originate from the composed ``PrefixNameConstraintsPolicy``
    /// on the ReaderAuth path; since C5 has already cleared every other RFC 5280 sub-check, that is
    /// a NameConstraints violation.
    private static func profileViolation(
        from failures: [CertificateValidationResult.PolicyFailure]
    ) -> CoseVerificationFailure {
        guard let reason = failures.first?.policyFailureReason.description else {
            // No policy reason available: treat as an untrusted certificate rather than inventing a
            // profile diagnostic.
            return .untrustedCertificate
        }

        if ownProfileReasons.contains(reason) {
            return .certificateProfileViolation(reason: reason)
        }
        return .certificateProfileViolation(reason: CertificateProfileReason.nameConstraints)
    }
}

private extension ASN1ObjectIdentifier {
    /// ISO 18013-5 mDL ExtendedKeyUsage OIDs enforced on the end-entity certificate.
    enum MDLEKU {
        /// IssuerAuth (mdlDS) — `1.0.18013.5.1.2`.
        static let issuerAuth: ASN1ObjectIdentifier = [1, 0, 18013, 5, 1, 2]
        /// ReaderAuth (mdlReaderAuth) — `1.0.18013.5.1.6`.
        static let readerAuth: ASN1ObjectIdentifier = [1, 0, 18013, 5, 1, 6]
    }
}
