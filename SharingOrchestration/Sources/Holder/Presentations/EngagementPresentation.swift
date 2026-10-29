import Foundation

public struct EngagementPresentation: Equatable, Hashable, Sendable {
    public let qrPayload: String?
    public let cancelRequiresConfirmation: Bool?
}
