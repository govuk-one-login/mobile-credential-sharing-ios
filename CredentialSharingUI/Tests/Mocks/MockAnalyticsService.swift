import Foundation

@testable import CredentialSharingUI

final class MockAnalyticsService: SharingAnalyticsService {
    private(set) var trackedScreens: [SharingScreen] = []
    private(set) var trackedEvents: [SharingEvent] = []
    private(set) var trackedErrorDescriptions: [String?] = []

    func trackScreen(_ screen: SharingScreen, with errorDescription: String?) {
        trackedScreens.append(screen)
        trackedErrorDescriptions.append(errorDescription)
    }

    func trackEvent(_ event: SharingEvent) {
        trackedEvents.append(event)
    }
}
