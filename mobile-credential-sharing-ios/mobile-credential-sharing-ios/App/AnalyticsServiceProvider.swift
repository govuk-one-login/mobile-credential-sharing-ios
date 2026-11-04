import Foundation
import protocol CredentialSharingUI.SharingAnalyticsService
import GAnalytics
import Logging

enum AnalyticsServiceProvider {
    static let shared: SharingAnalyticsService = makeAnalyticsService(bundle: .main)

    static func makeAnalyticsService(bundle: Bundle) -> SharingAnalyticsService {
        guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return DebugLoggingService()
        }
        GAnalytics.configure()
        let preferenceStore = UserDefaultsPreferenceStore()
        // Remove this force-accept once the analytics permissions screen is implemented.
        preferenceStore.hasAcceptedAnalytics = true
        let analytics = GAnalytics(
            analyticsPreferenceStore: preferenceStore
        )
        return analytics.addingAdditionalParameters(
            [
                "taxonomy_level1": "one login mobile application",
                "taxonomy_level2": "wallet"
            ]
        )
    }
}
