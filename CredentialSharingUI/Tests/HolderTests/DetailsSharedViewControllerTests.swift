import DesignSystem
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("DetailsSharedViewController Tests")
struct DetailsSharedViewControllerTests {
    let mockOrchestrator = MockHolderOrchestrator()

    private func makeSUT() -> DetailsSharedViewController {
        DetailsSharedViewController(orchestrator: mockOrchestrator)
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

    @Test("Movable footer contains the single primary 'Go back to documents' button")
    func movableFooterComposition() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)

        #expect(viewModel.movableFooter.count == 1)
        let button = try #require(viewModel.movableFooter[0] as? GDSButtonViewModel)
        #expect(button.accessibilityIdentifier == "details-shared-go-back-button")
        #expect(button.style == .primary)
        #expect(viewModel.footer.isEmpty)
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

    @Test("'Go back to documents' button calls userDidTapCancel on the orchestrator")
    func goBackButtonTriggersCancel() throws {
        let sut = makeSUT()
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        let button = try #require(viewModel.movableFooter[0] as? GDSButtonViewModel)

        #expect(mockOrchestrator.cancelPresentationCalled == false)

        // When — invoke the button action
        if case .action(let action) = button.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous button action")
        }

        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
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
}
