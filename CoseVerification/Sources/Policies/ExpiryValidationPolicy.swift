import Foundation
import SwiftASN1
import X509

/// Enforces the RFC 5280 §4.1.2.5 validity period (`notBefore`/`notAfter`) for every certificate in
/// the path — the leaf, every intermediate, and the trusted root the verifier appends.
///
/// This is C5's chain-wide "valid now?" check only. It deliberately does **not** evaluate
/// NameConstraints: those are enforced by ``PrefixNameConstraintsPolicy`` in C6, which applies the
/// RFC 5280 directoryName *prefix* matching the GDS ReaderAuth profile requires. Stock
/// ``X509/RFC5280Policy`` applies *exact* DN matching instead and would wrongly reject a legitimate
/// ReaderAuth leaf whose DN extends the constrained namespace — which is why it is not used here.
///
/// The validation instant defaults to now; tests inject a fixed instant for determinism.
struct ExpiryValidationPolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    private let validationTime: Date

    init(validationTime: Date = Date()) {
        self.validationTime = validationTime
    }

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for certificate in chain {
            if validationTime < certificate.notValidBefore {
                return .failsToMeetPolicy(
                    reason: "certificate not yet valid: \(certificate.subject)"
                )
            }
            if validationTime > certificate.notValidAfter {
                return .failsToMeetPolicy(
                    reason: "certificate expired: \(certificate.subject)"
                )
            }
        }
        return .meetsPolicy
    }
}
