import SwiftASN1
import X509

/// Requires the end-entity certificate's BasicConstraints to be either absent, or present asserting
/// `cA=false`.
///
/// Leaf-scoped: only `chain.leaf` is inspected; intermediates and the trusted root are unaffected.
///
/// Fails with the diagnostic ``CertificateProfileReason/basicConstraints``.
struct EndEntityBasicConstraintsPolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        guard let basicConstraintsExtension =
                chain.leaf.extensions[oid: .X509ExtensionID.basicConstraints] else {
            // Absent is permitted.
            return .meetsPolicy
        }

        // Present: it must decode and assert cA=false.
        guard let basicConstraints = try? BasicConstraints(basicConstraintsExtension),
              case .notCertificateAuthority = basicConstraints else {
            return .failsToMeetPolicy(reason: CertificateProfileReason.basicConstraints)
        }
        return .meetsPolicy
    }
}
