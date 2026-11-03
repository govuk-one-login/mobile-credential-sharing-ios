import DesignSystem
import GDSAnalytics
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("More About DVS Screen Tests")
struct MoreAboutDVSViewModelTests {
    let analyticsService = MockAnalyticsService()

    private func makeViewModel(
        onClose: @escaping () -> Void = {}
    ) -> MoreAboutDVSViewModel {
        MoreAboutDVSViewModel(
            presentation: ConsentPresentation(
                dvsName: "Yoti Ltd",
                documentType: DocumentType(
                    displayLabel: "Driving Licence",
                    documentIcon: UIImage()
                ),
                attributes: [],
                privacyPolicyURL: URL(string: "https://example.com/privacy")!
            ),
            analyticsService: analyticsService,
            onClose: onClose
        )
    }

    @Test("Right bar button is a Close button")
    func closeBarButton() throws {
        let buttons = try #require(makeViewModel().rightBarButtons)
        #expect(buttons.count == 1)
        let button = try #require(buttons.first)
        #expect(button.accessibilityIdentifier == "more-about-dvs-close-button")
    }

    @Test("Close returns to the consent screen and does not cancel the session")
    func closeReturnsToConsent() throws {
        var onCloseCalled = false
        let viewModel = makeViewModel { onCloseCalled = true }

        let expectedEvent = ButtonEvent(textKey: "close", bundle: .module)

        #expect(analyticsService.logEventCallCount == 0)

        let closeButton = try #require(viewModel.rightBarButtons?.first)
        let action = try #require(closeButton.action)
        action()

        // Close navigates back to consent via onClose rather than terminating the session.
        #expect(onCloseCalled)

        // didDismiss is unused: close is driven entirely by the bar button action.
        #expect(viewModel.didDismiss == nil)

        // Analytics for the close button is still tracked.
        #expect(analyticsService.logEventCallCount == 1)
        #expect(analyticsService.loggedEvent?.name == expectedEvent.name.rawValue)
        #expect(analyticsService.loggedParameters != nil)
    }

    @Test("didAppear logs the screen view")
    func didAppearTracksScreenVisit() throws {
        let viewModel = makeViewModel()

        #expect(analyticsService.logEventCallCount == 0)

        if case let .action(action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.logEventCallCount == 1)
    }
}
