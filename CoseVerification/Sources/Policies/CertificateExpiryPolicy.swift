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
///
/// Mirrors swift-certificates' internal `RFC5280Policy.ExpiryPolicy`, comparing the public
/// `Date`-typed `notValidBefore`/`notValidAfter` since `tbsCertificate` is internal to X509.
struct CertificateExpiryPolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    private let validationTime: Date

    init(validationTime: Date = Date()) {
        self.validationTime = validationTime
    }

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for certificate in chain {
            if case .failsToMeetPolicy(let reason) = Self.evaluate(certificate, at: validationTime) {
                return .failsToMeetPolicy(reason: reason)
            }
        }
        return .meetsPolicy
    }

    /// Evaluates one certificate's validity interval against `validationTime`. This is the core of
    /// the policy and the seam unit tests drive directly, since `UnverifiedCertificateChain` cannot
    /// be constructed outside the X509 module.
    static func evaluate(_ certificate: Certificate, at validationTime: Date) -> PolicyEvaluationResult {
        let notValidBefore = certificate.notValidBefore
        let notValidAfter = certificate.notValidAfter

        if notValidBefore > notValidAfter {
            return .failsToMeetPolicy(
                reason: "ExpiryPolicy: Certificate \(certificate) has invalid expiry, "
                    + "notValidAfter is earlier than notValidBefore"
            )
        }
        if validationTime < notValidBefore {
            return .failsToMeetPolicy(
                reason: "ExpiryPolicy: Certificate \(certificate) is not yet valid"
            )
        }
        if validationTime > notValidAfter {
            return .failsToMeetPolicy(
                reason: "ExpiryPolicy: Certificate \(certificate) has expired"
            )
        }
        return .meetsPolicy
    }
}
