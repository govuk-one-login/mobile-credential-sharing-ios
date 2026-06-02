import AVFoundation
import GDSCommon
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
struct VerifierContainerTests {
    let mockOrchestrator = MockVerifierOrchestrator()

    @Test("viewWillAppear calls startVerification on orchestrator")
    func viewWillAppearCallsStart() {
        let sut = VerifierContainer(orchestrator: mockOrchestrator)
        #expect(mockOrchestrator.startVerificationCalled == false)

        sut.viewWillAppear(false)

        #expect(mockOrchestrator.startVerificationCalled == true)
    }

    @Test("presentationControllerDidDismiss calls cancelVerification on orchestrator")
    func dismissCallsCancel() throws {
        let container = VerifierContainer(orchestrator: mockOrchestrator)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        #expect(mockOrchestrator.cancelVerificationCalled == false)

        sut.presentationControllerDidDismiss(try #require(sut.presentationController))

        #expect(mockOrchestrator.cancelVerificationCalled == true)
    }

    @Test("orchestrator didUpdateState .preflight displays PreflightPermissionViewController")
    func preflightStateDisplaysPreflightPermissionViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator)
        let state = VerifierSessionState.preflight(
            missingPrerequisites: [.bluetooth(.authorizationNotDetermined)]
        )
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController.viewControllers.count == 2)
        #expect(
            navigationController.viewControllers
                .contains(where: { $0 is PreflightPermissionViewController })
        )
    }

    @Test("orchestrator didUpdateState .readyToScan pushes to ScanningViewController")
    func readyToScanPushesToScanningViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // Push a view to simulate preflight screen being present
        baseNavigationController.pushViewController(UIViewController(), animated: false)
        #expect(baseNavigationController.viewControllers.count == 2)

        // When
        sut.orchestrator(didUpdateState: .readyToScan)

        // Then
        #expect(baseNavigationController.viewControllers.count == 3)
        #expect(baseNavigationController.viewControllers.last is ScanningViewController<AVCaptureSession>)
    }

    @Test("orchestrator didUpdateState .failed displays ErrorViewController")
    func failedStateDisplaysErrorViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator)
        let state = VerifierSessionState.failed(.unrecoverablePrerequisite(.bluetooth(.authorizationDenied)))
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController.viewControllers.count == 2)
        #expect(
            navigationController.viewControllers
                .contains(where: { $0 is ErrorViewController })
        )
    }
}
