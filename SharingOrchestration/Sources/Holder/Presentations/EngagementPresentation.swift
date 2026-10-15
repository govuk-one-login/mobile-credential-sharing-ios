import Foundation

public struct EngagementPresentation: Equatable, Hashable, Sendable {
    let qrPayload: String?
    let cancelRequiresConfirmation: Bool?
}
