import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI
@testable import DesignSystem

@MainActor
@Suite("Loading Screen Tests")
struct LoadingViewModelTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let analyticsService = MockAnalyticsService()

    private func makeViewModel(isCancellable: Bool) -> LoadingViewModel {
        LoadingViewModel(
            orchestrator: mockOrchestrator,
            isCancellable: isCancellable,
            analyticsService: analyticsService
        )
    }

    private func progressIndicator(in viewModel: LoadingViewModel) -> GDSProgressIndicatorViewModel? {
        viewModel.body.compactMap { $0 as? GDSProgressIndicatorViewModel }.first
    }

    // MARK: - Layout composition

    @Test("Screen style is centred", arguments: [true, false])
    func screenStyleIsCentred(isCancellable: Bool) {
        let style = makeViewModel(isCancellable: isCancellable).screenStyle
        #expect(style.verticalAlignment == .center)
        #expect(style.horizontalAlignment == .fill)
    }

    @Test("Body contains a single progress indicator", arguments: [true, false])
    func bodyContainsProgressIndicator(isCancellable: Bool) throws {
        let viewModel = makeViewModel(isCancellable: isCancellable)
        #expect(viewModel.body.count == 1)
        let indicator = try #require(progressIndicator(in: viewModel))
        #expect(indicator.accessibilityIdentifier == "loading-progress-indicator")
    }

    @Test("Back button is hidden", arguments: [true, false])
    func backButtonHidden(isCancellable: Bool) {
        #expect(makeViewModel(isCancellable: isCancellable).backButtonIsHidden)
    }

    // MARK: - Cancel bar button presence

    @Test("Cancellable screen exposes a Cancel right bar button")
    func cancellableShowsCancelButton() throws {
        let viewModel = makeViewModel(isCancellable: true)
        let buttons = try #require(viewModel.rightBarButtons)
        #expect(buttons.count == 1)
        #expect(buttons.first?.accessibilityIdentifier == "loading-cancel-button")
    }

    @Test("Non-cancellable screen has no right bar buttons")
    func nonCancellableHasNoCancelButton() {
        #expect(makeViewModel(isCancellable: false).rightBarButtons == nil)
    }

    // MARK: - Cancel interaction

    @Test("Tapping Cancel routes to the orchestrator")
    func cancelRoutesToOrchestrator() throws {
        let viewModel = makeViewModel(isCancellable: true)
        let button = try #require(viewModel.rightBarButtons?.first)

        #expect(mockOrchestrator.cancelPresentationCalled == false)
        let action = try #require(button.action)
        action()

        #expect(mockOrchestrator.cancelPresentationCalled)
    }

    @Test("Tapping Cancel logs a button event")
    func cancelLogsButtonEvent() throws {
        let viewModel = makeViewModel(isCancellable: true)
        let button = try #require(viewModel.rightBarButtons?.first)

        let action = try #require(button.action)
        action()

        let expected = ButtonEvent(textKey: "cancel", bundle: CredentialSharingUIResources.bundle)
        #expect(analyticsService.loggedEvent?.name == expected.name.rawValue)
        let parameters = try #require(analyticsService.loggedParameters)
        #expect(parameters["text"] as? String == expected.parameters["text"])
    }

    // MARK: - Screen view analytics

    @Test("didAppear logs a screenView for the getting-list-of-details screen ID")
    func cancellableLogsScreenView() throws {
        let viewModel = makeViewModel(isCancellable: true)

        if case let .action(action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.loggedEvent?.name == ScreenViewEventName.screenView.rawValue)
        let parameters = try #require(analyticsService.loggedParameters)
        #expect(parameters["screen_id"] as? String == AnalyticsScreen.gettingListOfDetails.id)
        #expect(parameters["screen_class"] as? String == ScreenClass.modal.rawValue)
        #expect(parameters["is_error"] as? String == "false")
    }

    @Test("didAppear logs a screenView for the sharing-your-details screen ID")
    func nonCancellableLogsScreenView() throws {
        let viewModel = makeViewModel(isCancellable: false)

        if case let .action(action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.loggedEvent?.name == ScreenViewEventName.screenView.rawValue)
        let parameters = try #require(analyticsService.loggedParameters)
        #expect(parameters["screen_id"] as? String == AnalyticsScreen.sharingYourDetails.id)
        #expect(parameters["screen_class"] as? String == ScreenClass.modal.rawValue)
    }

    @Test("The two loading screens report distinct Firebase screen IDs")
    func screenIdsAreDistinct() {
        #expect(AnalyticsScreen.gettingListOfDetails.id == "06328966-cd42-49c4-a573-9140ace45297")
        #expect(AnalyticsScreen.sharingYourDetails.id == "aedea082-0575-4f4e-babf-b2221d74756f")
        #expect(AnalyticsScreen.gettingListOfDetails.id != AnalyticsScreen.sharingYourDetails.id)
    }

    // MARK: - View controller

    @Test("View controller loads its view from the view model", arguments: [true, false])
    func viewControllerLoads(isCancellable: Bool) {
        let sut = LoadingViewController(
            orchestrator: mockOrchestrator,
            isCancellable: isCancellable,
            analyticsService: analyticsService
        )
        _ = sut.view
        #expect(sut.viewModel is LoadingViewModel)
    }
}
