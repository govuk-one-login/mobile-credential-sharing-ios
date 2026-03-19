import Logging
import Foundation
@testable import mobile_credential_sharing_ios
import Testing

struct DebugLoggingServiceTests {
    let sut: DebugLoggingService
    let mockPreferenceStore: MockAnalyticsPreferenceStore

    init() {
        mockPreferenceStore = MockAnalyticsPreferenceStore()
        sut = DebugLoggingService(analyticsPreferenceStore: mockPreferenceStore)
    }

    @Test("init sets preference store")
    func initSetsPreferenceStore() {
        #expect(sut.analyticsPreferenceStore is MockAnalyticsPreferenceStore)
    }

    @Test("init sets empty additional parameters")
    func initSetsEmptyAdditionalParameters() {
        #expect(sut.additionalParameters.isEmpty)
    }

    @Test("adding additional parameters merges parameters")
    func addingAdditionalParametersMerges() {
        sut.additionalParameters = ["key1": "value1"]

        _ = sut.addingAdditionalParameters(["key2": "value2"])

        #expect(sut.additionalParameters.count == 2)
        #expect(sut.additionalParameters["key1"] as? String == "value1")
        #expect(sut.additionalParameters["key2"] as? String == "value2")
    }

    @Test("adding additional parameters prefers existing values")
    func addingAdditionalParametersPrefersExisting() {
        sut.additionalParameters = ["key1": "existing"]

        _ = sut.addingAdditionalParameters(["key1": "new"])

        #expect(sut.additionalParameters["key1"] as? String == "existing")
    }

    @Test("adding additional parameters returns self")
    func addingAdditionalParametersReturnsSelf() {
        let result = sut.addingAdditionalParameters(["key": "value"])

        #expect(result === sut)
    }

    @Test("trackScreen does not throw")
    func trackScreenDoesNotThrow() {
        let screen = MockScreen()
        #expect(throws: Never.self) {
            sut.trackScreen(screen, parameters: ["param": "value"])
        }
    }

    @Test("logEvent does not throw")
    func logEventDoesNotThrow() {
        let event = MockEvent()
        #expect(throws: Never.self) {
            sut.logEvent(event, parameters: ["param": "value"])
        }
    }

    @Test("logCrash with NSError does not throw")
    func logCrashNSErrorDoesNotThrow() {
        let error = NSError(domain: "test", code: 1)
        #expect(throws: Never.self) {
            sut.logCrash(error)
        }
    }

    @Test("logCrash with Error does not throw")
    func logCrashErrorDoesNotThrow() {
        let error = MockError.testError
        #expect(throws: Never.self) {
            sut.logCrash(error)
        }
    }
}

// MARK: - Mocks
final class MockAnalyticsPreferenceStore: AnalyticsPreferenceStore {
    var hasAcceptedAnalytics: Bool?

    func stream() -> AsyncStream<Bool> {
        AsyncStream { _ in }
    }
}

struct MockScreen: LoggableScreen {
    var name: String { "MockScreen" }
    var type: MockScreenType { .test }
}

enum MockScreenType: CustomStringConvertible {
    case test

    var description: String { "test" }
}

struct MockEvent: LoggableEvent {
    var name: String { "MockEvent" }
}

enum MockError: Error {
    case testError
}
