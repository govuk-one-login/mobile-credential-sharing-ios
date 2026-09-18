/// Diagnostic reasons attached to ``CoseVerificationFailure/certificateProfileViolation(reason:)``.
///
/// Each value names the profile rule that failed, per the DCMAW-22160 acceptance-criteria table.
/// They exist for logging and debugging only — callers do not branch on the text.
///
/// The C6 profile policies emit these strings as their ``X509/PolicyFailureReason``. The
/// ``CertificateProfileValidator`` maps a policy failure straight through to
/// `certificateProfileViolation(reason:)`, so the reason a caller receives is exactly one of these.
enum CertificateProfileReason {
    static let version = "Version"
    static let serialNumber = "SerialNumber"
    static let subject = "Subject"
    static let basicConstraints = "BasicConstraints"
    static let keyUsage = "KeyUsage"
    static let extendedKeyUsage = "ExtendedKeyUsage"
    static let validityPeriod = "ValidityPeriod"
    static let nameConstraints = "NameConstraints"
}
