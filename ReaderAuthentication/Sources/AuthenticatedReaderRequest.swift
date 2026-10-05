import ExchangeFormat
import Foundation

/// Result of successful privacy-metadata validation: the candidate request
/// together with the verified privacy-policy URL.
///
/// Produced after both signature/certificate verification and privacy-policy
/// validation have passed for a candidate.
public struct AuthenticatedReaderRequest: Sendable, Equatable {

    /// The candidate document request that passed authentication.
    public let docRequest: RequestedDocument

    /// The validated privacy-policy URL for the verified Reader.
    public let privacyPolicyURL: URL

    /// The raw `organizationName` (O) from the verified Reader leaf's subject.
    ///
    /// Extracted exactly as it appears, with no validation. `nil` if the subject
    /// has no `organizationName` attribute.
    public let organizationName: String?

    public init(
        docRequest: RequestedDocument,
        privacyPolicyURL: URL,
        organizationName: String?
    ) {
        self.docRequest = docRequest
        self.privacyPolicyURL = privacyPolicyURL
        self.organizationName = organizationName
    }
}
