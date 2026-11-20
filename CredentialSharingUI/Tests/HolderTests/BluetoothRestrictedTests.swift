import CredentialSharingTestFixtures
import DesignSystem
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("Bluetooth Restricted Screen Tests")
struct BluetoothRestrictedTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let analyticsService = MockSharingAnalyticsService()

    private func makeViewModel() -> BluetoothRestrictedViewModel {
        BluetoothRestrictedViewModel(
            presentation: ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.authorizationRestricted)],
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
    }

    @Test("Body is error title followed by three distinct paragraphs")
    func bodyComposition() {
        let viewModel = makeViewModel()
        #expect(viewModel.body.count == 4)
        #expect(viewModel.body.first is GDSErrorIconTitleViewModel)

        let texts = viewModel.body.compactMap { $0 as? GDSTextViewModel }
        #expect(texts.map { $0.accessibilityIdentifier } == [
            "bluetooth-restricted-body1",
            "bluetooth-restricted-body2",
            "bluetooth-restricted-body3"
        ])
        #expect(texts.map { $0.title.stringKey } == [
            "bluetoothRestrictedParagraph1",
            "bluetoothRestrictedParagraph2",
            "bluetoothRestrictedParagraph3"
        ])
    }

    @Test("No navigation bar buttons, back button hidden, no static footer")
    func chrome() {
        let viewModel = makeViewModel()
        #expect(viewModel.rightBarButtons == nil)
        #expect(viewModel.backButtonIsHidden)
        #expect(viewModel.footer.isEmpty)
    }

    @Test("Go back to documents is the only movable footer button")
    func goBackButtonPresent() throws {
        let buttons = makeViewModel().movableFooter.compactMap { $0 as? GDSButtonViewModel }
        let button = try #require(buttons.first)
        #expect(buttons.count == 1)
        #expect(button.accessibilityIdentifier == "go-back-to-documents-button")
        #expect(button.title == GDSLocalisedString(stringKey: "goBackToDocumentsButton", bundle: .module).value)
    }

    @Test("Go back to documents tracks the button event and cancels without confirmation")
    func goBackTapped() throws {
        let viewModel = makeViewModel()
        let button = try #require(viewModel.movableFooter.first as? GDSButtonViewModel)
        guard case let .action(action) = button.buttonAction else {
            Issue.record("Expected an .action button action")
            return
        }
        action()

        #expect(analyticsService.trackedEvents == [.goBackToDocumentsButton])
        #expect(mockOrchestrator.cancelPresentationCalled)
    }

    @Test("didAppear logs the screen view")
    func didAppearTracksScreenVisit() {
        let viewModel = makeViewModel()
        if case let .action(action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }
        #expect(analyticsService.trackedScreens == [.bluetoothRestricted])
    }

    @Test("ReadinessViewController selects BluetoothRestrictedViewModel when authorization is restricted")
    func viewControllerSelectsRestricted() {
        let sut = ReadinessViewController(
            presentation: ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.authorizationRestricted)],
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            onCancel: {}
        )
        _ = sut.view
        #expect(sut.viewModel is BluetoothRestrictedViewModel)
    }
}
