import Foundation
import Logging

final class MockAnalyticsService: AnalyticsService {
    var analyticsPreferenceStore: AnalyticsPreferenceStore = MockAnalyticsPreferenceStore()
    var additionalParameters: [String: Any] = [:]

    private(set) var loggedEvent: LoggableEvent?
    private(set) var loggedParameters: [String: Any]?

    func addingAdditionalParameters(_ additionalParameters: [String: Any]) -> Self {
        self
    }

    func trackScreen(_ screen: any LoggableScreen, parameters: [String: Any]) {}
    func logEvent(_ event: LoggableEvent, parameters: [String: Any]) {
        loggedEvent = event
        loggedParameters = parameters
    }
    func logCrash(_ crash: NSError) {}
    func logCrash(_ crash: Error) {}
}

final class MockAnalyticsPreferenceStore: AnalyticsPreferenceStore {
    var hasAcceptedAnalytics: Bool?
    
    func stream() -> AsyncStream<Bool> {
        AsyncStream { _ in }
    }
}
