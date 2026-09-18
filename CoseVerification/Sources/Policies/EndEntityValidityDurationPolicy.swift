import Foundation
import SwiftASN1
import X509

/// Requires the end-entity certificate's validity duration (`notValidAfter - notValidBefore`) to be
/// no greater than a role-specific maximum.
///
/// IssuerAuth allows at most 457 days; ReaderAuth allows at most 1187 days. This is distinct from
/// the current-time interval check (whether the certificate is valid *now*), which C5 performs for
/// every certificate. This policy only bounds the leaf's total span.
///
/// Leaf-scoped: only `chain.leaf` is inspected.
///
/// Fails with the diagnostic ``CertificateProfileReason/validityPeriod``.
struct EndEntityValidityDurationPolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    private let maximumValidity: TimeInterval

    /// - Parameter maximumValidityDays: The maximum permitted leaf validity duration, in days.
    init(maximumValidityDays: Int) {
        self.maximumValidity = TimeInterval(maximumValidityDays) * 24 * 60 * 60
    }

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        let leaf = chain.leaf
        let duration = leaf.notValidAfter.timeIntervalSince(leaf.notValidBefore)
        guard duration <= maximumValidity else {
            return .failsToMeetPolicy(reason: CertificateProfileReason.validityPeriod)
        }
        return .meetsPolicy
    }
}
