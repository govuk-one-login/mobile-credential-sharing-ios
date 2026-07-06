import Foundation

public struct URIMetadata: Sendable, Equatable {
    public let clientID: String
    public let clientIdentifierPrefix: ClientIdentifierPrefix
    public let responseType: String
    public let nonce: String
    public let requestURI: URL

    public init(
        clientID: String,
        clientIdentifierPrefix: ClientIdentifierPrefix,
        responseType: String,
        nonce: String,
        requestURI: URL
    ) {
        self.clientID = clientID
        self.clientIdentifierPrefix = clientIdentifierPrefix
        self.responseType = responseType
        self.nonce = nonce
        self.requestURI = requestURI
    }
}
