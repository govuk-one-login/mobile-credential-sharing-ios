#if DEBUG
import Foundation
import Logging

public final class MockAnalyticsService: AnalyticsService {
    public var analyticsPreferenceStore: AnalyticsPreferenceStore = MockAnalyticsPreferenceStore()
    public var additionalParameters: [String: Any] = [:]

    public private(set) var loggedEvent: LoggableEvent?
    public private(set) var loggedParameters: [String: Any]?
    public private(set) var logEventCallCount = 0

    public init() {}

    public func addingAdditionalParameters(_ additionalParameters: [String: Any]) -> Self {
        self
    }

    public func trackScreen(_ screen: any LoggableScreen, parameters: [String: Any]) {}
    public func logEvent(_ event: LoggableEvent, parameters: [String: Any]) {
        logEventCallCount += 1
        loggedEvent = event
        loggedParameters = parameters
    }
    public func logCrash(_ crash: NSError) {}
    public func logCrash(_ crash: Error) {}
}

public final class MockAnalyticsPreferenceStore: AnalyticsPreferenceStore {
    public var hasAcceptedAnalytics: Bool?

    public init() {}

    public func stream() -> AsyncStream<Bool> {
        AsyncStream { _ in }
    }
}
#endif
