import SwiftASN1
import X509

/// Requires the end-entity certificate to carry a KeyUsage extension containing **exactly**
/// `digitalSignature` and no other usage bits.
///
/// Leaf-scoped: only `chain.leaf` is inspected. There is no KeyUsage criticality requirement.
///
/// The usage is read via ``Certificate/Extensions/tolerantKeyUsage``, which tolerates the
/// non-minimal BIT STRING padding emitted by AWS Private CA (see ``KeyUsageValidator``). The
/// semantics are unchanged: the extension must decode to exactly digitalSignature, and an absent or
/// malformed extension still fails.
///
/// Fails with the diagnostic ``CertificateProfileReason/keyUsage``.
struct EndEntityKeyUsagePolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    /// The only permitted KeyUsage for the end-entity: digitalSignature, nothing else.
    private let requiredKeyUsage = KeyUsage(digitalSignature: true)

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        guard chain.leaf.extensions.tolerantKeyUsage == requiredKeyUsage else {
            return .failsToMeetPolicy(reason: CertificateProfileReason.keyUsage)
        }
        return .meetsPolicy
    }
}
