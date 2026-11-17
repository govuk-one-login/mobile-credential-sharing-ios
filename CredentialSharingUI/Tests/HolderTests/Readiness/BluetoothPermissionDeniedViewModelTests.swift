import CredentialSharingTestFixtures
import DesignSystem
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("Bluetooth Permission Denied Screen Tests")
struct BluetoothPermissionDeniedViewModelTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let analyticsService = MockSharingAnalyticsService()

    private func makeViewModel(
        openSettings: @escaping @MainActor () -> Void = {}
    ) -> BluetoothPermissionDeniedViewModel {
        BluetoothPermissionDeniedViewModel(
            analyticsService: analyticsService,
            openSettings: openSettings,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
    }

    private func buttons(in viewModel: BluetoothPermissionDeniedViewModel) -> [GDSButtonViewModel] {
        viewModel.movableFooter.compactMap { $0 as? GDSButtonViewModel }
    }

    /// Runs a `DesignSystem.Action` if it's a synchronous `.action`, otherwise records a test issue.
    private func triggerSynchronousAction(_ action: DesignSystem.Action?, named elementName: String) {
        guard case let .action(handler) = action else {
            Issue.record("Expected a synchronous .action for \(elementName)")
            return
        }
        handler()
    }

    // MARK: - Routing

    @Test("Denied Bluetooth authorisation maps to the permission denied view model")
    func routing() {
        let viewModel = ReadinessViewController.viewModel(
            for: ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.authorizationDenied)],
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            onCancel: {}
        )
        #expect(viewModel is BluetoothPermissionDeniedViewModel)
    }

    // MARK: - Layout composition

    @Test("Body is error icon title, intro, numbered steps, then footnote")
    func bodyComposition() {
        let viewModel = makeViewModel()
        #expect(viewModel.body.count == 4)

        #expect(viewModel.body[0] is GDSErrorIconTitleViewModel)
        #expect(viewModel.body[1] is GDSTextViewModel)
        #expect(viewModel.body[2] is GDSListViewModel)
        #expect(viewModel.body[3] is GDSTextViewModel)

        let identifiers = viewModel.body.map { $0.accessibilityIdentifier }
        #expect(identifiers == [
            "bluetooth-denied-title",
            "bluetooth-denied-body",
            "bluetooth-denied-steps",
            "bluetooth-denied-footnote"
        ])
    }

    @Test("Buttons live in the movable footer; fixed footer is empty")
    func footerComposition() {
        let viewModel = makeViewModel()
        #expect(viewModel.footer.isEmpty)
        #expect(viewModel.movableFooter.count == 2)
        #expect(buttons(in: viewModel).count == 2)
    }

    @Test("Primary is Go to phone settings with an arrow icon; secondary is Cancel and go back")
    func buttonStylesAndIdentifiers() throws {
        let footerButtons = buttons(in: makeViewModel())

        let primary = try #require(footerButtons.first)
        #expect(primary.accessibilityIdentifier == "bluetooth-denied-go-to-settings-button")
        #expect(primary.style == .primary)
        let primaryIcon = try #require(primary.icon?.forState(.normal))
        #expect(primaryIcon.icon == "arrow.up.right")
        #expect(primaryIcon.position == .trailing)
        #expect(primaryIcon.accessibilityHint == "opens in settings")

        let secondary = try #require(footerButtons.last)
        #expect(secondary.accessibilityIdentifier == "bluetooth-denied-cancel-button")
        #expect(secondary.style == .secondary)
        #expect(secondary.icon == nil)
    }

    @Test("There is no navigation bar Cancel button")
    func noNavigationBarCancel() {
        #expect(makeViewModel().rightBarButtons == nil)
    }

    // MARK: - Interaction & Analytics

    @Test("Go to phone settings opens Settings and tracks the button event")
    func goToSettings() throws {
        var openedSettings = false
        let viewModel = makeViewModel(openSettings: { openedSettings = true })
        #expect(analyticsService.trackedEvents.isEmpty)

        triggerSynchronousAction(try #require(buttons(in: viewModel).first).buttonAction, named: "settings button")

        #expect(openedSettings)
        #expect(analyticsService.trackedEvents == [.goToPhoneSettingsButton])
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Cancel and go back cancels without confirmation and tracks the button event")
    func cancelAndGoBack() throws {
        var openedSettings = false
        let viewModel = makeViewModel(openSettings: { openedSettings = true })
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        triggerSynchronousAction(try #require(buttons(in: viewModel).last).buttonAction, named: "cancel button")

        #expect(mockOrchestrator.cancelPresentationCalled)
        #expect(analyticsService.trackedEvents == [.cancelAndGoBackButton])
        #expect(openedSettings == false)
    }

    @Test("didAppear logs the screen view")
    func didAppearTracksScreenView() {
        let viewModel = makeViewModel()
        #expect(analyticsService.trackedScreens.isEmpty)

        triggerSynchronousAction(viewModel.didAppear, named: "didAppear")

        #expect(analyticsService.trackedScreens == [.bluetoothPermissionDenied])
    }
}
