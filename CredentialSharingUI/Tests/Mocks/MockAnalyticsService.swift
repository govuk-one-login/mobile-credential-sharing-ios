import Foundation
import Logging

final class MockAnalyticsService: AnalyticsService {
    var analyticsPreferenceStore: AnalyticsPreferenceStore = MockAnalyticsPreferenceStore()
    var additionalParameters: [String: Any] = [:]

    private(set) var loggedEvent: LoggableEvent?
    private(set) var loggedParameters: [String: Any]?
    private(set) var logEventCallCount = 0
    private(set) var loggedEvents: [(name: String, parameters: [String: Any])] = []

    func addingAdditionalParameters(_ additionalParameters: [String: Any]) -> Self {
        self
    }

    func trackScreen(_ screen: any LoggableScreen, parameters: [String: Any]) {}
    func logEvent(_ event: LoggableEvent, parameters: [String: Any]) {
        logEventCallCount += 1
        loggedEvent = event
        loggedParameters = parameters
        loggedEvents.append((event.name, parameters))
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
