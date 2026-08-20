import Foundation

/// The validity period extracted from a verified leaf certificate.
///
/// Represents the `notBefore` and `notAfter` bounds of the certificate's
/// validity window. Callers use these values to enforce time-based policies
/// (e.g. maximum leaf validity duration) in their domain logic.
public struct CertificateValidityPeriod: Equatable, Sendable {
    /// The earliest date at which the certificate is valid.
    public let notBefore: Date

    /// The latest date at which the certificate is valid.
    public let notAfter: Date

    /// Creates a new validity period.
    /// - Parameters:
    ///   - notBefore: The earliest date at which the certificate is valid.
    ///   - notAfter: The latest date at which the certificate is valid.
    public init(notBefore: Date, notAfter: Date) {
        self.notBefore = notBefore
        self.notAfter = notAfter
    }
}
