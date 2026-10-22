import DesignSystem
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("Get Ready To Share Screen Tests")
struct GetReadyToShareTests {
    let mockOrchestrator = MockHolderOrchestrator()

    private func makeViewModel(
        missingPrerequisites: [MissingPrerequisite] = [.bluetooth(.statePoweredOff)]
    ) -> GetReadyToShareViewModel {
        GetReadyToShareViewModel(
            presentation: ReadinessPresentation(
                missingPrerequisites: missingPrerequisites,
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator
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

    @Test("Right bar button is the localised Cancel key")
    func cancelBarButton() throws {
        let title = try #require(makeViewModel().rightBarButtonTitle)
        #expect(title.stringKey == "cancel")
    }

    @Test("Back button is hidden")
    func backButtonHidden() {
        #expect(makeViewModel().backButtonIsHidden)
    }

    // MARK: - Interaction

    @Test("Allow Bluetooth resolves the Bluetooth prerequisite via the orchestrator")
    func allowBluetoothResolvesPrerequisite() throws {
        let viewModel = makeViewModel(missingPrerequisites: [.bluetooth(.statePoweredOff)])
        let primary = try #require(buttons(in: viewModel).first)

        #expect(mockOrchestrator.resolveCalled == false)

        if case let .action(action) = primary.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous .action for the primary button")
        }

        #expect(mockOrchestrator.resolveCalled)
        #expect(mockOrchestrator.resolvedPrerequisite == .bluetooth(.statePoweredOff))
    }

    @Test("Find out how sharing works is a no-op (out of scope) and does not resolve")
    func findOutHowIsNoOp() throws {
        let viewModel = makeViewModel()
        let secondary = try #require(buttons(in: viewModel).last)

        if case let .action(action) = secondary.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous .action for the secondary button")
        }

        #expect(mockOrchestrator.resolveCalled == false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Cancel (didDismiss) routes to the orchestrator")
    func cancelRoutesToOrchestrator() throws {
        let viewModel = makeViewModel()

        #expect(mockOrchestrator.cancelPresentationCalled == false)

        if case let .action(action) = viewModel.didDismiss {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didDismiss")
        }

        #expect(mockOrchestrator.cancelPresentationCalled)
    }

    // MARK: - View controller

    @Test("ReadinessViewController loads the Get ready to share view model for non powered-off prerequisites")
    func viewControllerLoads() {
        let sut = ReadinessViewController(
            presentation: ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.authorizationNotDetermined)],
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator
        )
        _ = sut.view
        #expect(sut.viewModel is GetReadyToShareViewModel)
    }
}
