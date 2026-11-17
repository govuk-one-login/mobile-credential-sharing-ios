import CredentialSharingTestFixtures
import SharingLogging
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI
@testable import DesignSystem

@MainActor
@Suite("Progress Screen Tests")
struct ProgressViewModelTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let analyticsService = MockSharingAnalyticsService()

    private func makeViewModel(
        stage: ProgressPresentation.ProgressPhase,
        cancelRequiresConfirmation: Bool?
    ) -> ProgressViewModel {
        ProgressViewModel(
            presentation: ProgressPresentation(
                phase: stage,
                cancelRequiresConfirmation: cancelRequiresConfirmation
            ),
            analyticsService: analyticsService,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
    }

    /// The cancellable establishment screen. Production now requires
    /// confirmation before cancelling; the view model only uses the flag's
    /// presence (non-nil) to decide whether to show the Cancel control, so the
    /// confirmation routing itself is exercised in HolderNavigationControllerTests.
    private func gettingListViewModel() -> ProgressViewModel {
        makeViewModel(stage: .processingRequest, cancelRequiresConfirmation: true)
    }

    /// The non-cancellable response screen.
    private func sharingDetailsViewModel() -> ProgressViewModel {
        makeViewModel(stage: .sendingResponse, cancelRequiresConfirmation: nil)
    }

    private func progressIndicator(in viewModel: ProgressViewModel) -> GDSProgressIndicatorViewModel? {
        viewModel.body.compactMap { $0 as? GDSProgressIndicatorViewModel }.first
    }

    // MARK: - Layout composition

    @Test("Screen style is centred")
    func screenStyleIsCentred() {
        for viewModel in [gettingListViewModel(), sharingDetailsViewModel()] {
            let style = viewModel.screenStyle
            #expect(style.verticalAlignment == .center)
            #expect(style.horizontalAlignment == .fill)
        }
    }

    @Test("Body contains a single progress indicator")
    func bodyContainsProgressIndicator() throws {
        for viewModel in [gettingListViewModel(), sharingDetailsViewModel()] {
            #expect(viewModel.body.count == 1)
            let indicator = try #require(progressIndicator(in: viewModel))
            #expect(indicator.accessibilityIdentifier == "progress-progress-indicator")
        }
    }

    @Test("Back button is hidden")
    func backButtonHidden() {
        #expect(gettingListViewModel().backButtonIsHidden)
        #expect(sharingDetailsViewModel().backButtonIsHidden)
    }

    // MARK: - Cancel bar button presence

    @Test("Screen with a cancellation status exposes a Cancel right bar button")
    func cancellableShowsCancelButton() throws {
        let viewModel = gettingListViewModel()
        let buttons = try #require(viewModel.rightBarButtons)
        #expect(buttons.count == 1)
        #expect(buttons.first?.accessibilityIdentifier == "right-bar-button")
    }

    @Test("Screen without a cancellation status has no right bar buttons")
    func nonCancellableHasNoCancelButton() {
        #expect(sharingDetailsViewModel().rightBarButtons == nil)
    }

    // MARK: - Cancel interaction

    @Test("Tapping Cancel routes through the onCancel closure")
    func cancelRoutesThroughOnCancel() throws {
        let viewModel = gettingListViewModel()
        let button = try #require(viewModel.rightBarButtons?.first)

        #expect(mockOrchestrator.cancelPresentationCalled == false)
        let action = try #require(button.action)
        action()

        #expect(mockOrchestrator.cancelPresentationCalled)
    }

    @Test("Tapping Cancel logs a cancel event")
    func cancelLogsButtonEvent() throws {
        let viewModel = gettingListViewModel()
        let button = try #require(viewModel.rightBarButtons?.first)

        let action = try #require(button.action)
        action()

        #expect(analyticsService.trackedEvents == [.cancel])
    }

    // MARK: - Screen view analytics

    @Test("didAppear logs a screenView for the getting-list-of-details screen")
    func cancellableLogsScreenView() throws {
        let viewModel = gettingListViewModel()

        if case let .action(action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.trackedScreens == [.gettingListOfDetails])
    }

    @Test("didAppear logs a screenView for the sharing-your-details screen")
    func nonCancellableLogsScreenView() throws {
        let viewModel = sharingDetailsViewModel()

        if case let .action(action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.trackedScreens == [.sharingYourDetails])
    }

    @Test("The two progress screens report distinct Firebase screen IDs")
    func screenIdsAreDistinct() {
        #expect(SharingScreen.gettingListOfDetails.id == "06328966-cd42-49c4-a573-9140ace45297")
        #expect(SharingScreen.sharingYourDetails.id == "aedea082-0575-4f4e-babf-b2221d74756f")
        #expect(SharingScreen.gettingListOfDetails.id != SharingScreen.sharingYourDetails.id)
    }

    // MARK: - View controller

    @Test("View controller loads its view from the view model")
    func viewControllerLoads() {
        for stage in [ProgressPresentation.ProgressPhase.processingRequest, .sendingResponse] {
            let sut = ProgressViewController(
                presentation: ProgressPresentation(phase: stage, cancelRequiresConfirmation: nil),
                analyticsService: analyticsService,
                onCancel: {}
            )
            _ = sut.view
            #expect(sut.viewModel is ProgressViewModel)
        }
    }
}
