import SwiftASN1
import X509

/// Requires every intermediate certificate to carry a KeyUsage extension that asserts **at least**
/// `keyCertSign` and `cRLSign`. Additional usage bits are permitted and ignored.
///
/// Scoped to intermediates only (see ``UnverifiedCertificateChain/intermediates``): the end-entity
/// and the trusted root are excluded. There is no KeyUsage criticality requirement.
///
/// The usage is read via ``Certificate/Extensions/tolerantKeyUsage``, which tolerates the
/// non-minimal BIT STRING padding emitted by AWS Private CA (see ``KeyUsageValidator``), and checked
/// with ``KeyUsage/contains(_:)`` — a superset test. An absent or malformed extension, or one
/// missing a required bit, fails.
///
/// Fails with the diagnostic ``CertificateProfileReason/keyUsage``.
struct IntermediateKeyUsagePolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    /// The usages an intermediate must assert, at minimum: keyCertSign + cRLSign.
    private let requiredKeyUsage = KeyUsage(keyCertSign: true, cRLSign: true)

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for intermediate in chain.intermediates {
            guard intermediate.extensions.tolerantKeyUsage?.contains(requiredKeyUsage) == true else {
                return .failsToMeetPolicy(reason: CertificateProfileReason.keyUsage)
            }
        }
        return .meetsPolicy
    }
}
