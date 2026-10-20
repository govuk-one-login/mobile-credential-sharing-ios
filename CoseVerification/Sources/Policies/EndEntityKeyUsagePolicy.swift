import SwiftASN1
import X509

/// Requires the end-entity certificate to carry a KeyUsage extension that asserts **at least**
/// `digitalSignature`. Additional usage bits are permitted and ignored.
///
/// Leaf-scoped: only `chain.leaf` is inspected. There is no KeyUsage criticality requirement.
///
/// The usage is read via ``Certificate/Extensions/tolerantKeyUsage``, which tolerates the
/// non-minimal BIT STRING padding emitted by AWS Private CA (see ``KeyUsageValidator``), and checked
/// with ``KeyUsage/contains(_:)`` — a superset test. An absent or malformed extension, or one
/// missing the required bit, fails.
///
/// Fails with the diagnostic ``CertificateProfileReason/keyUsage``.
struct EndEntityKeyUsagePolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    /// The usage the end-entity must assert, at minimum: digitalSignature.
    private let requiredKeyUsage = KeyUsage(digitalSignature: true)

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        guard chain.leaf.extensions.tolerantKeyUsage?.contains(requiredKeyUsage) == true else {
            return .failsToMeetPolicy(reason: CertificateProfileReason.keyUsage)
        }
        return .meetsPolicy
    }
}
