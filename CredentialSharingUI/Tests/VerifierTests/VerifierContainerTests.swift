import AVFoundation
import GDSCommon
import SharingCryptoService
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI
// swiftlint:disable type_body_length
// swiftlint:disable file_length

@MainActor
struct VerifierContainerTests {
    let mockOrchestrator = MockVerifierOrchestrator()
    let testConfig: VerifierConfig

    init() throws {
        let testAttributeGroup = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .portrait, intentToRetain: false),
                .init(attribute: .ageOver(21), intentToRetain: false)
            ]
        ))
        testConfig = VerifierConfig(
            attributeRequest: testAttributeGroup,
            trustedIssuerCertificate: TestCertificate.issuer
        )
    }

    @Test("viewWillAppear calls startVerification on orchestrator")
    func viewWillAppearCallsStart() throws {
        let sut = VerifierContainer(
            orchestrator: mockOrchestrator,
            config: testConfig
        )

        #expect(mockOrchestrator.startVerificationCalled == false)

        sut.viewWillAppear(false)

        #expect(mockOrchestrator.startVerificationCalled == true)
        #expect(mockOrchestrator.startVerificationConfig?.attributeRequest == testConfig.attributeRequest)
    }

    @Test("presentationControllerDidAttemptToDismiss calls didTapCancel on container")
    func dismissCallsCancel() throws {
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        #expect(mockOrchestrator.cancelVerificationCalled == false)

        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        #expect(mockOrchestrator.cancelVerificationCalled == true)
    }

    @Test("orchestrator didUpdateState .preflight displays PreflightPermissionViewController")
    func preflightStateDisplaysPreflightPermissionViewController() throws {
        // Given
        let sut = VerifierContainer(
            orchestrator: mockOrchestrator,
            config: testConfig
        )
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
        let sut = VerifierContainer(
            orchestrator: mockOrchestrator,
            config: testConfig
        )
        
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
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
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

    @Test("orchestrator didUpdateState .processingEngagement pushes LoadingViewController")
    func processingEngagementPushesLoadingViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // When
        sut.orchestrator(didUpdateState: .processingEngagement)

        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController.viewControllers.count == 2)
        let loadingVC = try #require(navigationController.viewControllers.last as? LoadingViewController)
        #expect(loadingVC.loadingTitle == "Processing...")
    }

    @Test("orchestrator didUpdateState .connecting pushes LoadingViewController")
    func connectingPushesLoadingViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // When
        sut.orchestrator(didUpdateState: .connecting)

        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController.viewControllers.count == 2)
        let loadingVC = try #require(navigationController.viewControllers.last as? LoadingViewController)
        #expect(loadingVC.loadingTitle == "Connecting...")
    }

    @Test("orchestrator didUpdateState .verifying pushes LoadingViewController")
    func verifyingPushesLoadingViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // When
        sut.orchestrator(didUpdateState: .verifying)

        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController.viewControllers.count == 2)
        let loadingVC = try #require(navigationController.viewControllers.last as? LoadingViewController)
        #expect(loadingVC.loadingTitle == "Verifying...")
    }

    @Test("orchestrator didUpdateState .cancelled dismisses navigation")
    func cancelledStateDismissesNavigation() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // When
        sut.orchestrator(didUpdateState: .cancelled)

        // Then - no new view controllers pushed
        #expect(baseNavigationController.viewControllers.count == 1)
    }

    @Test("orchestrator didUpdateState .success pushes AttributeResultViewController")
    func successStatePushesAttributeResultViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        let deviceResponse = DeviceResponse(
            documents: nil,
            documentErrors: nil,
            status: .ok
        )

        // When
        sut.orchestrator(didUpdateState: .success(deviceResponse))

        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController.viewControllers.count == 2)
        #expect(navigationController.viewControllers.last is AttributeResultViewController)
    }

    @Test("orchestrator didUpdateState nil does not push any view controller")
    func nilStateDoesNotPushViewController() throws {
        // Given
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        _ = sut.view
        _ = baseNavigationController.view

        // When
        sut.orchestrator(didUpdateState: nil)

        // Then
        #expect(baseNavigationController.viewControllers.count == 2)
        #expect(baseNavigationController.viewControllers.last is ErrorViewController)
    }

    // MARK: - Cancel Button Tests

    @Test("Pushed view controller receives a right Cancel button")
    func pushedViewControllerGetsCancelButton() {
        // Given
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        _ = sut.view
        let pushedVC = UIViewController()

        // When
        sut.navigationController(sut, willShow: pushedVC, animated: false)

        // Then
        #expect(pushedVC.navigationItem.rightBarButtonItem != nil)
        #expect(pushedVC.navigationItem.rightBarButtonItem?.title == "Cancel")
        #expect(pushedVC.navigationItem.rightBarButtonItem?.accessibilityIdentifier == "CancelButton")
    }

    @Test("Root VerifierContainer does not receive a Cancel button")
    func rootContainerDoesNotGetCancelButton() {
        // Given
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        _ = sut.view

        // When
        sut.navigationController(sut, willShow: container, animated: false)

        // Then
        #expect(container.navigationItem.rightBarButtonItem == nil)
    }

    @Test("Terminal screen (AttributeResultViewController) does not get Cancel button")
    func terminalScreenDoesNotGetCancelButton() {
        // Given
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        _ = sut.view
        let deviceResponse = DeviceResponse(documents: nil, documentErrors: nil, status: .ok)
        let terminalVC = AttributeResultViewController(deviceResponse: deviceResponse)

        // When
        sut.navigationController(sut, willShow: terminalVC, animated: false)

        // Then
        #expect(terminalVC.navigationItem.rightBarButtonItem == nil)
    }

    @Test("Error screen does not get Cancel button")
    func errorScreenDoesNotGetCancelButton() {
        // Given
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        _ = sut.view
        let errorVC = ErrorViewController(error: .generic("test"))

        // When
        sut.navigationController(sut, willShow: errorVC, animated: false)

        // Then
        #expect(errorVC.navigationItem.rightBarButtonItem == nil)
    }

    @Test("Cancel button triggers cancellation on the orchestrator")
    func cancelButtonTriggersCancellation() {
        // Given
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        _ = sut.view
        let pushedVC = UIViewController()
        sut.navigationController(sut, willShow: pushedVC, animated: false)
        #expect(mockOrchestrator.cancelVerificationCalled == false)

        // When
        _ = pushedVC.navigationItem.rightBarButtonItem?.target?.perform(
            pushedVC.navigationItem.rightBarButtonItem?.action
        )

        // Then
        #expect(mockOrchestrator.cancelVerificationCalled == true)
    }

    // MARK: - Cancel Confirmation Dialog Tests

    @Test("didTapCancel in active BLE state presents confirmation dialog with correct structure")
    func didTapCancelInActiveStatePresentsConfirmationDialog() throws {
        // Given
        let mockOrchestrator = MockVerifierOrchestrator()
        mockOrchestrator.shouldRequestCancelConfirmation = true
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let baseNavigationController = UINavigationController(rootViewController: sut)
        let window = UIWindow()
        window.rootViewController = baseNavigationController
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        // When
        sut.didTapCancel()

        // Then
        #expect(mockOrchestrator.cancelVerificationCalled == true)
        let alert = try #require(baseNavigationController.presentedViewController as? UIAlertController)
        #expect(alert.title == nil)
        #expect(alert.message == "Are you sure you want to cancel?")
        #expect(alert.actions.count == 2)
        #expect(alert.actions[0].title == "Yes")
        #expect(alert.actions[0].style == .destructive)
        #expect(alert.actions[1].title == "No")
        #expect(alert.actions[1].style == .cancel)
    }

    @Test("didConfirmCancel calls userDidConfirmCancel on orchestrator")
    func didConfirmCancelCallsUserDidConfirmCancel() {
        // Given
        let mockOrchestrator = MockVerifierOrchestrator()
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        #expect(mockOrchestrator.confirmCancelCalled == false)

        // When
        sut.didConfirmCancel()

        // Then
        #expect(mockOrchestrator.confirmCancelCalled == true)
    }

    @Test("didDismissCancel does not call userDidConfirmCancel on orchestrator")
    func didDismissCancelDoesNotCancel() {
        // Given
        let mockOrchestrator = MockVerifierOrchestrator()
        let sut = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        #expect(mockOrchestrator.confirmCancelCalled == false)

        // When
        sut.didDismissCancel()

        // Then
        #expect(mockOrchestrator.confirmCancelCalled == false)
    }

    @Test("isModalInPresentation is true by default")
    func isModalInPresentationTrueByDefault() {
        // Given
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)

        // Then
        #expect(sut.isModalInPresentation == true)
    }

    @Test("isModalInPresentation set to false for terminal screens")
    func isModalInPresentationFalseForTerminalScreens() {
        // Given
        let container = VerifierContainer(orchestrator: mockOrchestrator, config: testConfig)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        _ = sut.view
        let deviceResponse = DeviceResponse(documents: nil, documentErrors: nil, status: .ok)
        let terminalVC = AttributeResultViewController(deviceResponse: deviceResponse)

        // When
        sut.navigationController(sut, willShow: terminalVC, animated: false)

        // Then
        #expect(sut.isModalInPresentation == false)
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
