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
        for screen in [SharingScreen.getReadyToShare, .turnOnBluetooth, .detailsShared] {
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
            case .consent:
                #expect(mock.trackedScreenNames.first == "review what you’ll share")
            case .moreAboutDVS:
                #expect(mock.trackedScreenNames.first == "More about DVS")
            case .detailsShared:
                #expect(mock.trackedScreenNames.first == "details shared")
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

    // MARK: - trackEvent

    @Test("trackEvent logs under navigation with the resolved button copy as text")
    func trackEventForwardsButtonEvent() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        sut.trackEvent(.goBackToDocumentsButton)

        let tracked = try #require(mock.loggedEvents.first)
        #expect(tracked.name == EventName.navigation)
        #expect(tracked.text == "Go back to documents")
    }

    @Test("trackEvent substitutes the DVS literal so the real provider name is not logged")
    func trackEventSubstitutesDVSName() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        sut.trackEvent(.consentReadAboutButton)

        let tracked = try #require(mock.loggedEvents.first)
        #expect(tracked.text == "Read about DVS and their privacy notice")
    }

    @Test("Agree button logs its analytics copy without the item count")
    func trackEventAgreeDropsItemCount() throws {
        let mock = MockGDSAnalyticsService()
        let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

        sut.trackEvent(.consentAgreeButton)

        let tracked = try #require(mock.loggedEvents.first)
        #expect(tracked.text == "Agree and share details")
    }

    @Test("trackEvent resolves each event's catalog copy as the button text")
    func trackEventMapsAllEvents() {
        let expected: [SharingEvent: String] = [
            .cancel: "Cancel",
            .close: "Close",
            .getReadyToShareFindOutHowButton: "Find out how sharing works",
            .getReadyToShareAllowBluetoothButton: "Allow Bluetooth",
            .goBackToDocumentsButton: "Go back to documents",
            .consentCancelButton: "Cancel and go back to documents"
        ]

        for (event, text) in expected {
            let mock = MockGDSAnalyticsService()
            let sut = GDSSharingAnalyticsAdapter(analyticsService: mock)

            sut.trackEvent(event)

            #expect(mock.loggedEvents.first?.text == text)
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
        #expect(SharingScreen.moreAboutDVS.name == "CONSENT")
        #expect(SharingScreen.detailsShared.name == "RESOLUTION")
        #expect(SharingScreen.consent.name == "CONSENT")
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
