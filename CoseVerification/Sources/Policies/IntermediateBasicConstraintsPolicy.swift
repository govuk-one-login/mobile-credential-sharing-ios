import SwiftASN1
import X509

/// Requires every intermediate certificate to carry a **critical** BasicConstraints extension that
/// asserts `cA=true`.
///
/// Scoped to intermediates only (see ``UnverifiedCertificateChain/intermediates``): the end-entity
/// and the trusted root are excluded. The `pathLenConstraint`, when present, is enforced by the
/// library path build in C5; this policy enforces the presence, criticality, and `cA` value of the
/// extension itself.
///
/// Fails with the diagnostic ``CertificateProfileReason/basicConstraints``.
struct IntermediateBasicConstraintsPolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for intermediate in chain.intermediates {
            // BasicConstraints must be present…
            guard let basicConstraintsExtension =
                    intermediate.extensions[oid: .X509ExtensionID.basicConstraints] else {
                return .failsToMeetPolicy(reason: CertificateProfileReason.basicConstraints)
            }

            // …marked critical…
            guard basicConstraintsExtension.critical else {
                return .failsToMeetPolicy(reason: CertificateProfileReason.basicConstraints)
            }

            // …and assert cA=true.
            guard let basicConstraints = try? BasicConstraints(basicConstraintsExtension),
                  case .isCertificateAuthority = basicConstraints else {
                return .failsToMeetPolicy(reason: CertificateProfileReason.basicConstraints)
            }
        }
        return .meetsPolicy
    }
}
