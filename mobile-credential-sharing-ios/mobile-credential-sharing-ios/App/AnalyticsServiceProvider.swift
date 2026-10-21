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
        return GAnalytics(
            analyticsPreferenceStore: TempPreferenceStore()
        )
    }
}

/// To be replaced with UserDefaultsPreferenceStore() the view asking for analytics permissions is built
final class TempPreferenceStore: AnalyticsPreferenceStore {
    var hasAskedForAnalyticsPermissions: Bool? = true
    var hasAcceptedAnalytics: Bool? = true

    func stream() -> AsyncStream<Bool> {
        AsyncStream { _ in
            // temporary store always returns fixed values above, so no updates are ever emitted.
        }
    }
}
