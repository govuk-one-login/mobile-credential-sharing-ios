import Foundation

public struct EngagementPresentation: Equatable, Hashable, Sendable {
    public let qrPayload: String?
    public let cancelRequiresConfirmation: Bool?
    
    public init(
        qrPayload: String?,
        cancelRequiresConfirmation: Bool?
    ) {
        self.qrPayload = qrPayload
        self.cancelRequiresConfirmation = cancelRequiresConfirmation
    }
}
