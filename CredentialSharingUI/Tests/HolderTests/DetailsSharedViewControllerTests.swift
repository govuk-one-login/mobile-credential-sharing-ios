import DesignSystem
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("DetailsShared Screen Tests")
struct DetailsSharedViewControllerTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let mockAnalyticsService = MockAnalyticsService()

    private func makeViewModel() -> DetailsSharedViewModel {
        DetailsSharedViewModel(
            orchestrator: mockOrchestrator,
            analyticsService: mockAnalyticsService
        )
    }

    private func makeSUT() -> TerminalStateViewController {
        TerminalStateViewController(viewModel: makeViewModel())
    }

    @Test("View loads without crashing")
    func viewLoads() {
        let sut = makeSUT()
        _ = sut.view
        #expect(sut.view != nil)
    }

    @Test("View model is a DetailsSharedViewModel with a configured screen style")
    func usesExpectedViewModel() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        // Body/footer composition (below) confirms the screen layout.
        #expect(viewModel.body.isEmpty == false)
    }

    @Test("Body contains a tick icon, title and a single combined body paragraph")
    func bodyComposition() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)

        #expect(viewModel.body.count == 3)

        let tickIcon = try #require(viewModel.body[0] as? GDSImageViewModel)
        #expect(tickIcon.accessibilityIdentifier == "details-shared-tick-icon")

        let title = try #require(viewModel.body[1] as? GDSTextViewModel)
        #expect(title.accessibilityIdentifier == "details-shared-title")
        #expect(title.accessibilityTraits == .header)

        // One text view so VoiceOver reads both sentences as a single element.
        let body = try #require(viewModel.body[2] as? GDSTextViewModel)
        #expect(body.accessibilityIdentifier == "details-shared-body")
    }

    @Test("Movable footer contains the single pinned primary 'Go back to documents' button")
    func movableFooterComposition() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)

        // Button stays pinned in the movable footer (non-scrolling).
        #expect(viewModel.movableFooter.count == 1)
        #expect(viewModel.footer.isEmpty)

        let button = try #require(viewModel.movableFooter[0] as? GDSButtonViewModel)
        #expect(button.accessibilityIdentifier == "details-shared-go-back-button")
        // Primary style with design-specified 16pt fixed corners (not a capsule).
        #expect(button.style.cornerStyle == .fixed)
        #expect(button.style.cornerRadius == DesignSystem.CornerRadius.default)
        #expect(button.style.backgroundColor == GDSButtonStyle.primary.backgroundColor)
    }

    @Test("Footer bottom inset is zero so the pinned button does not float")
    func footerBottomInsetIsZero() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        #expect(viewModel.footerBottomInset == 0)
    }

    @Test("No Cancel bar button is shown on this screen")
    func noCancelBarButton() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        #expect(viewModel.rightBarButtonTitle == nil)
        // The back button is also hidden on this terminal screen.
        #expect(viewModel.backButtonIsHidden == true)
        #expect(viewModel.backButtonTitle == nil)
    }

    @Test("'Go back to documents' button finishes the journey via the orchestrator")
    func goBackButtonTriggersFinish() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        let button = try #require(viewModel.movableFooter[0] as? GDSButtonViewModel)

        #expect(mockOrchestrator.userDidFinishCalled == false)

        // When — invoke the button action
        if case .action(let action) = button.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous button action")
        }

        // Then — the journey is dismissed (not a session cancel, which no-ops in
        // the terminal success state).
        #expect(mockOrchestrator.userDidFinishCalled == true)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("didDismiss is not configured — the screen cannot be swipe/cancel dismissed")
    func didDismissIsNil() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        #expect(viewModel.didDismiss == nil)
    }

    @Test("didAppear action is configured for screen view tracking")
    func didAppearConfigured() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        // The action must be present so the screenView event fires on appear.
        if case .action = viewModel.didAppear {
            // Expected
        } else {
            Issue.record("Expected a synchronous didAppear action")
        }
    }

    @Test("didAppear dispatches a screenView event with the Details Shared firebase screen ID")
    func didAppearDispatchesScreenView() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)

        // Nothing logged until the screen appears.
        #expect(mockAnalyticsService.loggedEvent == nil)

        // When — invoke the didAppear action.
        if case .action(let action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous didAppear action")
        }

        // Then — a screenView event is recorded for the Details Shared screen.
        #expect(mockAnalyticsService.loggedEvent?.name == "screenView")
        let parameters = try #require(mockAnalyticsService.loggedParameters)
        #expect(parameters["screen_id"] as? String == "c2ccd487-c0e0-4ef8-943b-c555c4856a2c")
        #expect(parameters["screen_name"] as? String == "details shared")
        #expect(parameters["screen_class"] as? String == "modal")
        #expect(parameters["is_error"] as? String == "false")
        // Taxonomy defaults from the prerequisite analytics work.
        #expect(parameters["taxonomy_level1"] as? String == "one login mobile application")
        #expect(parameters["taxonomy_level2"] as? String == "wallet")
        #expect(parameters["taxonomy_level3"] as? String == "proximity sharing")
    }

    @Test("'Go back to documents' button dispatches a navigation button event")
    func goBackButtonDispatchesButtonEvent() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        let button = try #require(viewModel.movableFooter[0] as? GDSButtonViewModel)

        #expect(mockAnalyticsService.loggedEvent == nil)

        // When — invoke the button action.
        if case .action(let action) = button.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous button action")
        }

        // Then — a navigation button event carrying the button text is recorded.
        #expect(mockAnalyticsService.loggedEvent?.name == "navigation")
        let parameters = try #require(mockAnalyticsService.loggedParameters)
        #expect(parameters["text"] as? String == "go back to documents")
    }
}
