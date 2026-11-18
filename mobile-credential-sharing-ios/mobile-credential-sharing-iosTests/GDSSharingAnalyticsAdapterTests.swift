import CredentialSharingUI
import Foundation
import GDSAnalytics
import Logging
@testable import mobile_credential_sharing_ios
import SharingOrchestration
import Testing

@MainActor
@Suite("GDSSharingAnalyticsAdapter Tests")
struct GDSSharingAnalyticsAdapterTests {

    // MARK: - init

    @Test("init injects the proximity sharing taxonomy level 3 parameter")
    func initInjectsTaxonomyLevel3() {
        let mock = MockGDSAnalyticsService()

        _ = GDSSharingAnalyticsAdapter(analyticsService: mock)

        #expect(mock.addedParameters.count == 1)
        #expect(mock.addedParameters.first?["taxonomy_level3"] as? String == "proximity sharing")
    }

    // MARK: - trackScreen

    @Test("trackScreen forwards a ScreenView carrying the screen's title and firebase id")
    func trackScreenForwardsScreenView() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        sut.trackScreen(.getReadyToShare)

        // LoggableScreen.name is the ScreenView title (the resolved English copy,
        // formatted as a lowercased analytics parameter).
        #expect(mock.trackedScreenNames.first == "get ready to share")
        // Parameters carry the firebase screen id for the screen.
        let parameters = try #require(mock.trackedScreenParameters.first)
        #expect(parameters["screen_id"] as? String == SharingScreen.getReadyToShare.id)
    }

    @Test("trackScreen forwards each SharingScreen's title and id")
    func trackScreenMapsAllScreens() throws {
        for screen in [SharingScreen.getReadyToShare, .turnOnBluetooth, .detailsShared, .genericError] {
            let mock = MockGDSAnalyticsService()
            let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

            sut.trackScreen(screen)
            
            switch screen {
            case .getReadyToShare:
                #expect(mock.trackedScreenNames.first == "get ready to share")
            case .turnOnBluetooth:
                #expect(mock.trackedScreenNames.first == "turn on bluetooth")
            case .gettingListOfDetails:
                #expect(mock.trackedScreenNames.first == "getting list of details")
            case .sharingYourDetails:
                #expect(mock.trackedScreenNames.first == "sharing your details")
            case .qrCode:
                #expect(mock.trackedScreenNames.first == "find out which details you need to share")
            case .detailsShared:
                #expect(mock.trackedScreenNames.first == "details shared")
            case .genericError:
                #expect(mock.trackedScreenNames.first == "sharing is currently unavailable")
            case .error:
                #expect(mock.trackedScreenNames.first == "error")
            }
            
            let parameters = try #require(mock.trackedScreenParameters.first)
            #expect(parameters["screen_id"] as? String == screen.id)
        }
    }

    // MARK: - trackErrorScreen

    @Test("trackErrorScreen forwards an ErrorScreenView carrying the screen id and is_error flag")
    func trackErrorScreenForwardsErrorScreenView() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        sut.trackScreen(.error, with: SessionError.generic("Test title").errorDescription)

        // LoggableScreen.name resolves to the error screen title.
        #expect(mock.trackedScreenNames.first == "error")

        let parameters = try #require(mock.trackedScreenParameters.first)
        #expect(parameters["screen_id"] as? String == SharingScreen.error.id)
        #expect(parameters["is_error"] as? String == "true")
    }

    @Test("trackErrorScreen forwards the error's reason as a parameter")
    func trackErrorScreenForwardsErrorReason() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        // SessionError.reason == errorDescription; parameters are lowercased.
        sut.trackScreen(.error, with: SessionError.generic("Test title").errorDescription)

        let parameters = try #require(mock.trackedScreenParameters.first)
        #expect(parameters["reason"] as? String == "test title")
    }

    @Test("generic error screen is tracked as an error screen with its id, is_error flag and reason")
    func trackGenericErrorScreenForwardsErrorScreenViewWithReason() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        sut.trackScreen(.genericError, with: "Credential signing failed")

        // The title key must be resolved to English, not left as the raw key.
        #expect(mock.trackedScreenNames.first == "sharing is currently unavailable")

        let parameters = try #require(mock.trackedScreenParameters.first)
        #expect(parameters["screen_id"] as? String == "9bf821af-e8ff-41cf-a311-4b6cec989315")
        #expect(parameters["is_error"] as? String == "true")
        // Parameters are lowercased.
        #expect(parameters["reason"] as? String == "credential signing failed")
    }

    // MARK: - trackEvent

    @Test("trackEvent forwards a ButtonEvent carrying the event's English title as text")
    func trackEventForwardsButtonEvent() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        sut.trackEvent(.goBackToDocumentsButton)

        let tracked = try #require(mock.loggedEvents.first)
        #expect(tracked.name == EventName.navigation)
        #expect(tracked.text == "Go back to documents")
    }

    @Test("trackEvent maps every SharingEvent to its English title")
    func trackEventMapsAllEvents() {
        let events: [(event: SharingEvent, english: String)] = [
            (.cancel, "Cancel"),
            (.getReadyToShareFindOutHowButton, "Find out how sharing works"),
            (.getReadyToShareAllowBluetoothButton, "Allow Bluetooth"),
            (.goBackToDocumentsButton, "Go back to documents")
        ]

        for (event, english) in events {
            let mock = MockGDSAnalyticsService()
            let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

            sut.trackEvent(event)

            #expect(mock.loggedEvents.first?.text == english)
        }
    }
}

// MARK: - SharingScreen / ButtonEvent conformances

@Suite("Adapter type conformances")
struct AdapterConformanceTests {

    @Test("SharingScreen.name returns the screen class for the ScreenType conformance")
    func sharingScreenNameIsScreenClass() {
        #expect(SharingScreen.getReadyToShare.name == "READINESS")
        #expect(SharingScreen.turnOnBluetooth.name == "READINESS")
        #expect(SharingScreen.detailsShared.name == "RESOLUTION")
        #expect(SharingScreen.genericError.name == "RESOLUTION")
        #expect(SharingScreen.error.name == "ERROR")
    }

    @Test("ButtonEvent.name returns its 'navigation' for the LoggableEvent conformance")
    func buttonEventNameIsText() {
        let event = ButtonEvent(textKey: "Some button")
        #expect(event.name == EventName.navigation.rawValue)
    }
}

// MARK: - Mocks

/// Records what the adapter forwards to the underlying analytics service so the
/// mapping (`SharingScreen`/`SharingEvent` -> GDS types + parameters) can be asserted.
private final class MockGDSAnalyticsService: AnalyticsService {
    var analyticsPreferenceStore: AnalyticsPreferenceStore = MockAnalyticsPreferenceStore()
    var additionalParameters: [String: Any] = [:]

    private(set) var addedParameters: [[String: Any]] = []
    private(set) var trackedScreenNames: [String] = []
    private(set) var trackedScreenParameters: [[String: Any]] = []
    private(set) var loggedEvents: [ButtonEvent] = []

    func addingAdditionalParameters(_ additionalParameters: [String: Any]) -> Self {
        addedParameters.append(additionalParameters)
        self.additionalParameters.merge(additionalParameters) { current, _ in current }
        return self
    }

    func trackScreen(_ screen: any LoggableScreen, parameters: [String: Any]) {
        trackedScreenNames.append(screen.name)
        trackedScreenParameters.append(parameters)
    }

    func logEvent(_ event: LoggableEvent, parameters: [String: Any]) {
        if let buttonEvent = event as? ButtonEvent {
            loggedEvents.append(buttonEvent)
        }
    }

    func logCrash(_ crash: NSError) {}
    func logCrash(_ crash: Error) {}
}
