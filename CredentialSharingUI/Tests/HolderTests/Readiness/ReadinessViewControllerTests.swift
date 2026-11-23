import CredentialSharingTestFixtures
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ReadinessViewController Tests")
struct ReadinessViewControllerTests {
    let mockOrchestrator = MockHolderOrchestrator()

    private func makePresentation(
        _ missingPrerequisites: [MissingPrerequisite]
    ) -> ReadinessPresentation {
        ReadinessPresentation(
            missingPrerequisites: missingPrerequisites,
            cancelRequiresConfirmation: false
        )
    }

    private func makeSUT(
        _ missingPrerequisites: [MissingPrerequisite]
    ) -> ReadinessViewController {
        ReadinessViewController(
            presentation: makePresentation(missingPrerequisites),
            orchestrator: mockOrchestrator,
            onCancel: {}
        )
    }

    // MARK: - View model selection

    @Test("Bluetooth powered off selects the BluetoothPoweredOffViewModel")
    func poweredOffSelectsBluetoothPoweredOff() {
        let sut = makeSUT([.bluetooth(.statePoweredOff)])
        _ = sut.view
        #expect(sut.viewModel is BluetoothPoweredOffViewModel)
    }

    @Test("Bluetooth authorization not determined selects the GetReadyToShareViewModel")
    func authorizationNotDeterminedSelectsGetReadyToShare() {
        let sut = makeSUT([.bluetooth(.authorizationNotDetermined)])
        _ = sut.view
        #expect(sut.viewModel is GetReadyToShareViewModel)
    }

    @Test(
        "Other Bluetooth prerequisites fall back to the GetReadyToShareViewModel",
        arguments: [
            MissingPrerequisite.bluetooth(.authorizationDenied),
            .bluetooth(.authorizationRestricted),
            .bluetooth(.stateUnsupported),
            .bluetooth(.stateUnauthorized),
            .bluetooth(.stateResetting),
            .bluetooth(.stateUnknown)
        ]
    )
    func otherBluetoothPrerequisitesFallBack(prerequisite: MissingPrerequisite) {
        let sut = makeSUT([prerequisite])
        _ = sut.view
        #expect(sut.viewModel is GetReadyToShareViewModel)
    }

    @Test("No missing prerequisites falls back to the GetReadyToShareViewModel")
    func emptyPrerequisitesFallBack() {
        let sut = makeSUT([])
        _ = sut.view
        #expect(sut.viewModel is GetReadyToShareViewModel)
    }

    @Test("Only the first missing prerequisite determines the view model")
    func firstPrerequisiteWins() {
        let poweredOffFirst = makeSUT([
            .bluetooth(.statePoweredOff),
            .bluetooth(.authorizationNotDetermined)
        ])
        _ = poweredOffFirst.view
        #expect(poweredOffFirst.viewModel is BluetoothPoweredOffViewModel)

        let poweredOffSecond = makeSUT([
            .bluetooth(.authorizationNotDetermined),
            .bluetooth(.statePoweredOff)
        ])
        _ = poweredOffSecond.view
        #expect(poweredOffSecond.viewModel is GetReadyToShareViewModel)
    }

    // MARK: - Static mapping

    @Test("viewModel(for:) maps a presentation to the same type the controller uses")
    func staticMappingMatchesController() {
        let presentation = makePresentation([.bluetooth(.statePoweredOff)])
        let viewModel = ReadinessViewController.viewModel(
            for: presentation,
            orchestrator: mockOrchestrator,
            onCancel: {}
        )
        #expect(viewModel is BluetoothPoweredOffViewModel)
    }
}
