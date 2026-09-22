import SwiftASN1
import X509

/// Requires every intermediate certificate to carry a KeyUsage extension containing **exactly**
/// `keyCertSign` and `cRLSign` and no other usage bits.
///
/// Scoped to intermediates only (see ``UnverifiedCertificateChain/intermediates``): the end-entity
/// and the trusted root are excluded. There is no KeyUsage criticality requirement.
///
/// Fails with the diagnostic ``CertificateProfileReason/keyUsage``.
struct IntermediateKeyUsagePolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    /// The only permitted KeyUsage for an intermediate: keyCertSign + cRLSign, nothing else.
    private let requiredKeyUsage = KeyUsage(keyCertSign: true, cRLSign: true)

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for intermediate in chain.intermediates {
            guard let keyUsage = try? intermediate.extensions.keyUsage,
                  keyUsage == requiredKeyUsage else {
                return .failsToMeetPolicy(reason: CertificateProfileReason.keyUsage)
            }
        }
        return .meetsPolicy
    }
}
