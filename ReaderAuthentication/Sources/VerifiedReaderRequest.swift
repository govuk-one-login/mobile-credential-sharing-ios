import ExchangeFormat
import X509

/// Result of successful cryptographic and certificate verification: the
/// validated candidate request together with the verified Reader leaf
/// certificate.
///
/// This is an SDK-internal value produced by Reader Authentication verification
/// and handed to privacy-metadata validation. The certificate stays inside the
/// Reader Authentication boundary. Mirrors the Android `VerifiedReaderRequest`.
public struct VerifiedReaderRequest: Sendable, Equatable {

    /// The candidate document request whose Reader Authentication was verified.
    public let docRequest: RequestedDocument

    /// The verified Reader leaf certificate from the COSE `x5chain`.
    public let readerCertificate: Certificate

    public init(docRequest: RequestedDocument, readerCertificate: Certificate) {
        self.docRequest = docRequest
        self.readerCertificate = readerCertificate
    }
}
