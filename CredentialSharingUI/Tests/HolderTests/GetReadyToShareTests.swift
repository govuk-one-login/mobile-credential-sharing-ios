import DesignSystem
import GDSAnalytics
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("Get Ready To Share Screen Tests")
struct GetReadyToShareTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let analyticsService = MockAnalyticsService()

    private func makeViewModel(
        missingPrerequisites: [MissingPrerequisite] = [.bluetooth(.authorizationNotDetermined)]
    ) -> GetReadyToShareViewModel {
        GetReadyToShareViewModel(
            presentation: ReadinessPresentation(
                missingPrerequisites: missingPrerequisites,
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
    }

    private func buttons(in viewModel: GetReadyToShareViewModel) -> [GDSButtonViewModel] {
        viewModel.movableFooter.compactMap { $0 as? GDSButtonViewModel }
    }

    // MARK: - Layout composition

    @Test("Body contains the title and a single grouped paragraph block")
    func bodyComposition() {
        let viewModel = makeViewModel()
        #expect(viewModel.body.count == 2)
        #expect(viewModel.body.allSatisfy { $0 is GDSTextViewModel })

        let identifiers = viewModel.body
            .compactMap { ($0 as? GDSTextViewModel)?.accessibilityIdentifier }
        #expect(identifiers == ["get-ready-to-share-title", "get-ready-to-share-body"])
    }

    @Test("Both action buttons live in the movable footer; fixed footer is empty")
    func footerComposition() {
        let viewModel = makeViewModel()
        #expect(viewModel.footer.isEmpty)
        #expect(buttons(in: viewModel).count == 2)
    }

    @Test("Primary button is Allow Bluetooth, secondary is Find out how sharing works")
    func buttonStylesAndIdentifiers() throws {
        let footerButtons = buttons(in: makeViewModel())

        let primary = try #require(footerButtons.first)
        #expect(primary.accessibilityIdentifier == "get-ready-to-share-allow-bluetooth-button")

        let secondary = try #require(footerButtons.last)
        #expect(secondary.accessibilityIdentifier == "get-ready-to-share-find-out-how-button")
    }

    // MARK: - Cancel bar button

    @Test("Right bar button is the localised Cancel button")
    func cancelBarButton() throws {
        let barButton = try #require(makeViewModel().rightBarButtons?.first)
        #expect(barButton.accessibilityIdentifier == "right-bar-button")
        guard case let .button(title, _, _) = barButton.content else {
            Issue.record("Expected a .button content for the cancel bar button")
            return
        }
        #expect(title == GDSLocalisedString(stringKey: "cancel", bundle: .module).value)
    }

    @Test("No right bar button when cancel confirmation is unspecified")
    func noCancelBarButtonWhenConfirmationNil() {
        let viewModel = GetReadyToShareViewModel(
            presentation: ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.statePoweredOff)],
                cancelRequiresConfirmation: nil
            ),
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
        #expect(viewModel.rightBarButtons == nil)
    }

    @Test("Back button is hidden")
    func backButtonHidden() {
        #expect(makeViewModel().backButtonIsHidden)
    }

    // MARK: - Interaction & Analytics

    @Test("Allow Bluetooth resolves the Bluetooth prerequisite via the orchestrator")
    func allowBluetoothResolvesPrerequisite() throws {
        let viewModel = makeViewModel(missingPrerequisites: [.bluetooth(.statePoweredOff)])
        let primary = try #require(buttons(in: viewModel).first)
        let expectedEvent = ButtonEvent(
            textKey: "getReadyToShareAllowBluetoothButton",
            bundle: .module
        )
        
        #expect(analyticsService.logEventCallCount == 0)

        #expect(mockOrchestrator.resolveCalled == false)

        if case let .action(action) = primary.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous .action for the primary button")
        }

        #expect(mockOrchestrator.resolveCalled)
        #expect(mockOrchestrator.resolvedPrerequisite == .bluetooth(.statePoweredOff))
        #expect(analyticsService.logEventCallCount == 1)
        #expect(analyticsService.loggedEvent?.name == expectedEvent.name.rawValue)
        #expect(analyticsService.loggedParameters != nil)
    }

    @Test("Find out how sharing button action does not resolve and analytics event fires")
    func findOutHowIsNoOp() throws {
        let viewModel = makeViewModel()
        let secondary = try #require(buttons(in: viewModel).last)
        let expectedEvent = ButtonEvent(
            textKey: "getReadyToShareFindOutHowButton",
            bundle: .module
        )
        
        #expect(analyticsService.logEventCallCount == 0)

        if case let .action(action) = secondary.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous .action for the secondary button")
        }
        
        #expect(analyticsService.logEventCallCount == 1)
        #expect(analyticsService.loggedEvent?.name == expectedEvent.name.rawValue)
        #expect(analyticsService.loggedParameters != nil)
        #expect(mockOrchestrator.resolveCalled == false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Cancel bar button routes to the orchestrator and tracks analytics event")
    func cancelRoutesToOrchestrator() throws {
        let viewModel = makeViewModel()
        let expectedEvent = ButtonEvent(
            textKey: "cancel",
            bundle: .module
        )
        
        #expect(analyticsService.logEventCallCount == 0)
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        let barButton = try #require(viewModel.rightBarButtons?.first)
        let action = try #require(barButton.action)
        action()

        #expect(mockOrchestrator.cancelPresentationCalled)
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
        
        let parameters = try #require(analyticsService.loggedParameters)

        #expect(analyticsService.logEventCallCount == 1)
        #expect(analyticsService.loggedEvent?.name == ScreenViewEventName.screenView.rawValue)
        #expect(parameters["screen_class"] as? String == ScreenClass.modal.rawValue)
        #expect(parameters["is_error"] as? String == "false")
    }

    // MARK: - View controller

    @Test("ReadinessViewController loads the Get ready to share view model for non powered-off prerequisites")
    func viewControllerLoads() {
        let sut = ReadinessViewController(
            presentation: ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.authorizationNotDetermined)],
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
        _ = sut.view
        #expect(sut.viewModel is GetReadyToShareViewModel)
    }
}
