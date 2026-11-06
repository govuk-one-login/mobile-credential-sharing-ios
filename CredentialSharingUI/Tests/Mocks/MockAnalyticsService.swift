import Foundation

@testable import CredentialSharingUI

final class MockAnalyticsService: SharingAnalyticsService {
    private(set) var trackedScreens: [SharingScreen] = []
    private(set) var trackedEvents: [SharingEvent] = []
    private(set) var trackedErrors: [SessionError] = []

    func trackScreen(_ screen: SharingScreen) {
        trackedScreens.append(screen)
    }

    func trackEvent(_ event: SharingEvent) {
        trackedEvents.append(event)
    }
    
    func trackErrorScreen(_ screen: SharingScreen, with error: SessionError) {
        trackedScreens.append(screen)
        trackedErrors.append(error)
    }
}
