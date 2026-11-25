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
    
    @Test("Bluetooth authorization denied selects the BluetoothPermissionDeniedViewModel")
    func authorizationNotDeterminedSelectsBluetoothPermissionsDenied() {
        let sut = makeSUT([.bluetooth(.authorizationDenied)])
        _ = sut.view
        #expect(sut.viewModel is BluetoothPermissionDeniedViewModel)
    }

    @Test(
        "Restricted, unsupported and unauthorized Bluetooth render the BluetoothRestrictedViewModel",
        arguments: [
            MissingPrerequisite.bluetooth(.authorizationRestricted),
            .bluetooth(.stateUnsupported),
            .bluetooth(.stateUnauthorized)
        ]
    )
    func restrictedStatesSelectBluetoothRestricted(prerequisite: MissingPrerequisite) {
        let sut = makeSUT([prerequisite])
        _ = sut.view
        #expect(sut.viewModel is BluetoothRestrictedViewModel)
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
