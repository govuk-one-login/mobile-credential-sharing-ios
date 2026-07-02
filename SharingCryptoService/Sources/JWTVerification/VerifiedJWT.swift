import Foundation

public struct VerifiedJWT: Sendable, Equatable {
    public let headerData: Data
    public let payloadData: Data

    init(headerData: Data, payloadData: Data) {
        self.headerData = headerData
        self.payloadData = payloadData
    }
}
