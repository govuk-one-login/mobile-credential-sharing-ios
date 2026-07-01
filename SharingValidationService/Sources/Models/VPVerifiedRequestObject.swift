import Foundation

public struct VPVerifiedRequestObject: Sendable, Equatable {
    public let headerTyp: String?
    public let clientID: String?
    public let responseType: String?
    public let responseMode: String?
    public let responseURI: String?
    public let nonce: String?
    public let state: String?
    public let dcqlQueryData: Data?

    public init(
        headerTyp: String?,
        clientID: String?,
        responseType: String?,
        responseMode: String?,
        responseURI: String?,
        nonce: String?,
        state: String?,
        dcqlQueryData: Data?
    ) {
        self.headerTyp = headerTyp
        self.clientID = clientID
        self.responseType = responseType
        self.responseMode = responseMode
        self.responseURI = responseURI
        self.nonce = nonce
        self.state = state
        self.dcqlQueryData = dcqlQueryData
    }
}
