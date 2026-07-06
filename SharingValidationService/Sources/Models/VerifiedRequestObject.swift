import Foundation

public struct VerifiedRequestObject: Sendable, Equatable {
    public let headerTyp: String?
    public let aud: String?
    public let clientID: String?
    public let responseType: String?
    public let responseMode: String?
    public let responseURI: String?
    public let redirectURI: String?
    public let nonce: String?
    public let state: String?
    public let dcqlQueryData: Data?
    public let clientMetadataData: Data?

    /// `dNSName` Subject Alternative Names read from the leaf certificate in the JWS `x5c`
    /// header during signature verification. Empty when the request object was not signed
    /// with an X.509 certificate. Used to authenticate an `x509_san_dns:` `client_id`.
    public let leafCertificateSANs: [String]

    public init(
        headerTyp: String?,
        aud: String?,
        clientID: String?,
        responseType: String?,
        responseMode: String?,
        responseURI: String?,
        redirectURI: String?,
        nonce: String?,
        state: String?,
        dcqlQueryData: Data?,
        clientMetadataData: Data?,
        leafCertificateSANs: [String]
    ) {
        self.headerTyp = headerTyp
        self.aud = aud
        self.clientID = clientID
        self.responseType = responseType
        self.responseMode = responseMode
        self.responseURI = responseURI
        self.redirectURI = redirectURI
        self.nonce = nonce
        self.state = state
        self.dcqlQueryData = dcqlQueryData
        self.clientMetadataData = clientMetadataData
        self.leafCertificateSANs = leafCertificateSANs
    }
}
