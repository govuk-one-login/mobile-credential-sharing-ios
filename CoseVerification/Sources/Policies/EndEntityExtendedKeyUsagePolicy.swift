import SwiftASN1
import X509

/// Requires the end-entity certificate's ExtendedKeyUsage to **contain** a specific OID.
///
/// The required OID is role-specific: IssuerAuth requires `1.0.18013.5.1.2`, ReaderAuth requires
/// `1.0.18013.5.1.6`. The OID must be present, but ExtendedKeyUsage need not be critical and the
/// required OID need not be the only usage.
///
/// Leaf-scoped: only `chain.leaf` is inspected.
///
/// Fails with the diagnostic ``CertificateProfileReason/extendedKeyUsage``.
struct EndEntityExtendedKeyUsagePolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    private let requiredUsage: ExtendedKeyUsage.Usage

    /// - Parameter requiredOID: The ExtendedKeyUsage OID the end-entity must contain.
    init(requiredOID: ASN1ObjectIdentifier) {
        self.requiredUsage = ExtendedKeyUsage.Usage(oid: requiredOID)
    }

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        guard let extendedKeyUsage = try? chain.leaf.extensions.extendedKeyUsage,
              extendedKeyUsage.contains(requiredUsage) else {
            return .failsToMeetPolicy(reason: CertificateProfileReason.extendedKeyUsage)
        }
        return .meetsPolicy
    }
}
