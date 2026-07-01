import Foundation

public struct URIMetadata: Sendable, Equatable {
    public let clientID: String
    public let clientIdentifierPrefix: ClientIdentifierPrefix
    public let responseType: String
    public let nonce: String
    public let requestMode: RequestMode

    public enum RequestMode: Sendable, Equatable {
        case byValue(jwt: String)
        case byReference(requestURI: URL)
    }

    public init(
        clientID: String,
        clientIdentifierPrefix: ClientIdentifierPrefix,
        responseType: String,
        nonce: String,
        requestMode: RequestMode
    ) {
        self.clientID = clientID
        self.clientIdentifierPrefix = clientIdentifierPrefix
        self.responseType = responseType
        self.nonce = nonce
        self.requestMode = requestMode
    }
}
