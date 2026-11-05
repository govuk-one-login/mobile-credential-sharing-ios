import Foundation

@testable import CredentialSharingUI

final class MockAnalyticsService: SharingAnalyticsService {
    private(set) var trackedScreens: [SharingScreen] = []
    private(set) var trackedEvents: [SharingEvent] = []

    func trackScreen(_ screen: SharingScreen) {
        trackedScreens.append(screen)
    }

    func trackEvent(_ event: SharingEvent) {
        trackedEvents.append(event)
    }
}
