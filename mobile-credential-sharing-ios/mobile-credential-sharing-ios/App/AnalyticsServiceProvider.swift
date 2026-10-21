import Foundation
import GAnalytics
import Logging

enum AnalyticsServiceProvider {
    static let shared: AnalyticsService = makeAnalyticsService(bundle: .main)

    static func makeAnalyticsService(bundle: Bundle) -> AnalyticsService {
        guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return DebugLoggingService()
        }
        GAnalytics.configure()
        let preferenceStore = UserDefaultsPreferenceStore()
        // TODO: Remove this force-accept once the analytics permissions screen is implemented.
        preferenceStore.hasAcceptedAnalytics = true
        return GAnalytics(
            analyticsPreferenceStore: preferenceStore
        )
    }
}
