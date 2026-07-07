import Foundation

public struct VerifiedJWT: Sendable, Equatable {
    public let headerData: Data
    public let payloadData: Data

    /// `dNSName` Subject Alternative Names read from the leaf certificate in the `x5c` header.
    /// Empty when the certificate carries no SAN extension. Downstream validation uses these to
    /// authenticate an `x509_san_dns:` `client_id` against the signing certificate.
    public let leafCertificateSANs: [String]
    
    public init(
        headerData: Data,
        payloadData: Data,
        leafCertificateSANs: [String]
    ) {
        self.headerData = headerData
        self.payloadData = payloadData
        self.leafCertificateSANs = leafCertificateSANs
    }
}
