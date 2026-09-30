import ExchangeFormat
import Foundation
import X509

/// Contract for verifying Reader Authentication cryptographic signatures and
/// certificates for a single candidate request.
///
/// The concrete implementation (Story R4) rebuilds the signed
/// `ReaderAuthenticationBytes` from the candidate's preserved
/// `itemsRequestBytes` and the active transcript, calls `CoseVerification`
/// once, and maps any COSE failure onto a ``ReaderAuthenticationFailure``.
public protocol ReaderAuthenticator: Sendable {
    /// Verifies the Reader Authentication structure for a candidate request.
    ///
    /// - Parameters:
    ///   - candidateDocRequest: The decoded document request containing the
    ///     preserved `rawReaderAuth` and `itemsRequestBytes`.
    ///   - untaggedSessionTranscriptBytes: The exact active untagged session
    ///     transcript bytes.
    ///   - trustedReaderCertificates: The list of trusted Reader CA certificates.
    /// - Returns: A ``VerifiedReaderRequest`` on successful verification.
    /// - Throws: ``ReaderAuthenticationFailure`` if verification fails.
    func verify(
        candidateDocRequest: RequestedDocument,
        untaggedSessionTranscriptBytes: Data,
        trustedReaderCertificates: [Certificate]
    ) async throws -> VerifiedReaderRequest
}
