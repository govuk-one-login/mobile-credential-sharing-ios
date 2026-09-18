import SwiftASN1
import X509

/// Requires every certificate in the candidate chain to be X.509 **v3**.
///
/// This is a common rule: it applies to the end-entity, every intermediate, and the trusted root
/// (which the ``X509/Verifier`` appends to the chain before policy evaluation).
///
/// Fails with the diagnostic ``CertificateProfileReason/version``.
struct CertificateVersionPolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for certificate in chain where certificate.version != .v3 {
            return .failsToMeetPolicy(reason: CertificateProfileReason.version)
        }
        return .meetsPolicy
    }
}
