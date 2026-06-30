import Foundation

public struct RemoteSubmissionResult: Sendable, Equatable {
    public let redirectURI: URL?

    public init(redirectURI: URL?) {
        self.redirectURI = redirectURI
    }
}
