import SwiftASN1
import X509

/// Requires every certificate in the candidate chain to carry a serial number.
///
/// This is a common rule: it applies to the end-entity, every intermediate, and the trusted root
/// (appended by the ``X509/Verifier`` before policy evaluation).
///
/// A DER `INTEGER` always decodes to at least one byte, so an empty serial-number byte string means
/// the field was absent or degenerate.
///
/// Fails with the diagnostic ``CertificateProfileReason/serialNumber``.
struct SerialNumberPresentPolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for certificate in chain where certificate.serialNumber.bytes.isEmpty {
            return .failsToMeetPolicy(reason: CertificateProfileReason.serialNumber)
        }
        return .meetsPolicy
    }
}
