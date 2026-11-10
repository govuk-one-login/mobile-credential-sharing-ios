#if DEBUG
import Foundation
import SharingOrchestration

public final class MockSharingAnalyticsService: SharingAnalyticsService {
    public private(set) var trackedScreens: [SharingScreen] = []
    public private(set) var trackedEvents: [SharingEvent] = []
    public private(set) var trackedErrorDescriptions: [String?] = []

    public init() {}

    public func trackScreen(_ screen: SharingScreen, with errorDescription: String?) {
        trackedScreens.append(screen)
        trackedErrorDescriptions.append(errorDescription)
    }

    public func trackEvent(_ event: SharingEvent) {
        trackedEvents.append(event)
    }
}
#endif
