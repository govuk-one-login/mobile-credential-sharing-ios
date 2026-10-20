import Foundation
import GDSAnalytics
import Logging
@testable import mobile_credential_sharing_ios
import Testing

@Suite("AnalyticsService+Extension Tests")
struct AnalyticsServiceExtensionTests {
    let sut: MockAnalyticsService

    init() {
        sut = MockAnalyticsService()
    }

    // MARK: trackButtonEvent

    @Test("trackButtonEvent logs event name from the GDSAnalytics event")
    func trackButtonEventLogsName() {
        // Given
        let event = ButtonEvent(textKey: "test_button")

        // When
        sut.trackButtonEvent(event)

        // Then
        #expect(sut.loggedEvent?.name == event.name.rawValue)
    }

    @Test("trackButtonEvent merges event parameters over the screen view defaults")
    func trackButtonEventMergesParameters() throws {
        // Given
        let event = ButtonEvent(textKey: "test_button")

        // When
        sut.trackButtonEvent(event)

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["text"] as? String == event.parameters["text"])
        #expect(parameters["type"] as? String == event.parameters["type"])
        #expect(parameters["organisation"] as? String == "<OT1056>")
    }

    @Test("trackButtonEvent includes all taxonomy defaults")
    func trackButtonEventIncludesTaxonomyDefaults() throws {
        // Given
        let event = ButtonEvent(textKey: "test_button")

        // When
        sut.trackButtonEvent(event)

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["saved_doc_type"] as? String == "undefined")
        #expect(parameters["primary_publishing_organisation"] as? String ==
                "government digital service - digital identity")
        #expect(parameters["taxonomy_level1"] as? String == "one login mobile application")
        #expect(parameters["taxonomy_level2"] as? String == "document checking application")
        #expect(parameters["taxonomy_level3"] as? String == "driving licence cri")
        #expect(parameters["language"] as? String == NSLocale.current.identifier)
    }

    // MARK: trackScreenEvent

    @Test("trackScreenEvent logs the given event unchanged")
    func trackScreenEventLogsEvent() {
        // Given
        let event = MockLoggableEvent(name: "test_screen")

        // When
        sut.trackScreenEvent(event)

        // Then
        #expect(sut.loggedEvent?.name == "test_screen")
    }

    @Test("trackScreenEvent logs the screen view defaults as parameters")
    func trackScreenEventLogsDefaults() throws {
        // Given
        let event = MockLoggableEvent(name: "test_screen")

        // When
        sut.trackScreenEvent(event)

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["organisation"] as? String == "<OT1056>")
        #expect(parameters["language"] as? String == NSLocale.current.identifier)
    }
}

// MARK: - AnalyticsData Tests
@Suite("AnalyticsData Tests")
struct AnalyticsDataTests {

    @Test("screenViewDefaults contains all expected keys")
    func screenViewDefaultsContainsExpectedKeys() {
        // When
        let keys = AnalyticsData.screenViewDefaults.map(\.key)

        // Then
        #expect(keys == [
            "saved_doc_type",
            "primary_publishing_organisation",
            "organisation",
            "taxonomy_level1",
            "taxonomy_level2",
            "taxonomy_level3",
            "language"
        ])
    }

    @Test("Dictionary.screenViewDefaults reduces AnalyticsData.screenViewDefaults into a keyed dictionary")
    func dictionaryScreenViewDefaultsReducesCorrectly() {
        // When
        let defaults = [String: Any].screenViewDefaults

        // Then
        #expect(defaults.count == AnalyticsData.screenViewDefaults.count)
        #expect(defaults["organisation"] as? String == "<OT1056>")
        #expect(defaults["language"] as? String == NSLocale.current.identifier)
    }
}

// MARK: - Mocks
private struct MockLoggableEvent: LoggableEvent {
    let name: String
}

final class MockAnalyticsService: AnalyticsService {
    var analyticsPreferenceStore: AnalyticsPreferenceStore = MockAnalyticsPreferenceStore()
    var additionalParameters: [String: Any] = [:]

    private(set) var loggedEvent: LoggableEvent?
    private(set) var loggedParameters: [String: Any]?

    func addingAdditionalParameters(_ additionalParameters: [String: Any]) -> Self {
        self.additionalParameters.merge(additionalParameters) { existing, _ in existing }
        return self
    }

    func trackScreen(_ screen: any LoggableScreen, parameters: [String: Any]) {}

    func logEvent(_ event: LoggableEvent, parameters: [String: Any]) {
        loggedEvent = event
        loggedParameters = parameters
    }

    func logCrash(_ crash: NSError) {}

    func logCrash(_ crash: Error) {}
}
