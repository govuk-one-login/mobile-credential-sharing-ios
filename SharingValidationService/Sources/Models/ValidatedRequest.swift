import Foundation

public struct ValidatedRequest: Sendable, Equatable {
    public let dcqlQuery: DCQLQuery
    public let responseURI: URL
    public let state: String?
    public let nonce: String
    public let clientIdentifierPrefix: ClientIdentifierPrefix

    public init(
        dcqlQuery: DCQLQuery,
        responseURI: URL,
        state: String?,
        nonce: String,
        clientIdentifierPrefix: ClientIdentifierPrefix
    ) {
        self.dcqlQuery = dcqlQuery
        self.responseURI = responseURI
        self.state = state
        self.nonce = nonce
        self.clientIdentifierPrefix = clientIdentifierPrefix
    }
}
