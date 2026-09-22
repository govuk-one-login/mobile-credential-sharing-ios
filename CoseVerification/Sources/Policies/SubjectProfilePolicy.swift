import SwiftASN1
import X509

/// Requires every certificate's subject to carry a `commonName` and a `countryName` equal to `GB`.
///
/// This is a common rule: it applies to the end-entity, every intermediate, and the trusted root
/// (appended by the ``X509/Verifier`` before policy evaluation).
///
/// Fails with the diagnostic ``CertificateProfileReason/subject``.
struct SubjectProfilePolicy: VerifierPolicy {
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = []

    /// The `countryName` value every subject must carry.
    private let requiredCountryName = "GB"

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        for certificate in chain where !subjectMeetsProfile(certificate) {
            return .failsToMeetPolicy(reason: CertificateProfileReason.subject)
        }
        return .meetsPolicy
    }

    /// True when the subject has a `commonName` attribute and a `countryName` attribute equal to GB.
    private func subjectMeetsProfile(_ certificate: Certificate) -> Bool {
        var hasCommonName = false
        var countryName: String?

        for relativeName in certificate.subject {
            for attribute in relativeName {
                switch attribute.type {
                case .RDNAttributeType.commonName:
                    hasCommonName = true
                case .RDNAttributeType.countryName:
                    countryName = String(attribute.value)
                default:
                    continue
                }
            }
        }

        return hasCommonName && countryName == requiredCountryName
    }
}
