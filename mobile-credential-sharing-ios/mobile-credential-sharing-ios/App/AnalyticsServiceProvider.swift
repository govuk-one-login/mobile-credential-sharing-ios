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
            analyticsPreferenceStore: tempPreferenceStore()
        )
    }
}

struct TestEvent: LoggableEvent {
    let name = "test_event"
}

final class tempPreferenceStore: AnalyticsPreferenceStore {
    var hasAskedForAnalyticsPermissions: Bool? = true
    var hasAcceptedAnalytics: Bool? = true

    func stream() -> AsyncStream<Bool> {
        AsyncStream { _ in }
    }
}
