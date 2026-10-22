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
        #expect(parameters["taxonomy_level2"] as? String == "wallet")
        #expect(parameters["taxonomy_level3"] as? String == "proximity sharing")
        #expect(parameters["language"] as? String == NSLocale.current.identifier)
    }

    // MARK: trackScreenEvent

    @Test("trackScreenEvent logs the given event name unchanged")
    func trackScreenEventLogsEvent() {
        // Given / When
        sut.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: "Test Screen",
            screenClass: .modal,
            screenID: "test-id"
        )

        // Then
        #expect(sut.loggedEvent?.name == ScreenViewEventName.screenView.rawValue)
    }

    @Test("trackScreenEvent logs the screen view defaults as parameters")
    func trackScreenEventLogsDefaults() throws {
        // Given / When
        sut.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: "Test Screen",
            screenClass: .modal,
            screenID: "test-id"
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["organisation"] as? String == "<OT1056>")
        #expect(parameters["language"] as? String == NSLocale.current.identifier)
    }

    @Test("trackScreenEvent logs screen_name, screen_class and screen_id")
    func trackScreenEventLogsScreenParameters() throws {
        // Given / When
        sut.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: "Test Screen",
            screenClass: .errorScreen,
            screenID: "test-id"
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["screen_name"] as? String == "test screen")
        #expect(parameters["screen_class"] as? String == "errorscreen")
        #expect(parameters["screen_id"] as? String == "test-id")
    }

    @Test("trackScreenEvent defaults saved_doc_type to undefined when not provided")
    func trackScreenEventDefaultsSavedDocType() throws {
        // Given / When
        sut.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: "Test Screen",
            screenClass: .modal,
            screenID: "test-id"
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["saved_doc_type"] as? String == "undefined")
    }

    @Test("trackScreenEvent overrides saved_doc_type when provided")
    func trackScreenEventOverridesSavedDocType() throws {
        // Given / When
        sut.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: "Test Screen",
            screenClass: .modal,
            screenID: "test-id",
            savedDocType: "NiNo"
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["saved_doc_type"] as? String == "nino")
    }

    @Test("trackScreenEvent sets is_error false for screenView")
    func trackScreenEventSetsIsErrorFalse() throws {
        // Given / When
        sut.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: "Test Screen",
            screenClass: .modal,
            screenID: "test-id"
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["is_error"] as? String == "false")
    }

    @Test("trackScreenEvent sets is_error true for screenViewError")
    func trackScreenEventSetsIsErrorTrue() throws {
        // Given / When
        sut.trackScreenEvent(
            ScreenViewEventName.screenViewError,
            title: "Test Screen",
            screenClass: .errorScreen,
            screenID: "test-id"
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["is_error"] as? String == "true")
        #expect(sut.loggedEvent?.name == ScreenViewEventName.screenViewError.rawValue)
    }

    @Test("trackScreenEvent logs error fields when an error is provided")
    func trackScreenEventLogsErrorFields() throws {
        // Given
        let error = MockLoggableError(
            reason: "nfc chip was not found",
            endpoint: "https://domain.tld/route",
            statusCode: "500 gateway timeout",
            hash: "d49adb37cdc21549605db12241da690c"
        )

        // When
        sut.trackScreenEvent(
            ScreenViewEventName.screenViewError,
            title: "Test Screen",
            screenClass: .errorScreen,
            screenID: "test-id",
            error: error
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["reason"] as? String == "nfc chip was not found")
        #expect(parameters["endpoint"] as? String == "https://domain.tld/route")
        #expect(parameters["status"] as? String == "500 gateway timeout")
        #expect(parameters["hash"] as? String == "d49adb37cdc21549605db12241da690c")
    }

    @Test("trackScreenEvent omits error fields that are nil")
    func trackScreenEventOmitsNilErrorFields() throws {
        // Given
        let error = MockLoggableError(reason: "nfc chip was not found", endpoint: nil, statusCode: nil, hash: nil)

        // When
        sut.trackScreenEvent(
            ScreenViewEventName.screenViewError,
            title: "Test Screen",
            screenClass: .errorScreen,
            screenID: "test-id",
            error: error
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect(parameters["reason"] as? String == "nfc chip was not found")
        #expect(parameters["endpoint"] == nil)
        #expect(parameters["status"] == nil)
        #expect(parameters["hash"] == nil)
    }

    @Test("trackScreenEvent truncates values longer than 100 characters")
    func trackScreenEventTruncatesLongValues() throws {
        // Given
        let longTitle = String(repeating: "a", count: 150)

        // When
        sut.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: longTitle,
            screenClass: .modal,
            screenID: "test-id"
        )

        // Then
        let parameters = try #require(sut.loggedParameters)
        #expect((parameters["screen_name"] as? String)?.count == 100)
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
private struct MockLoggableError: LoggableError {
    let reason: String?
    let endpoint: String?
    let statusCode: String?
    let hash: String?
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
