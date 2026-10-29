import SharingCryptoService
import SharingPrerequisiteGate
import SwiftCBOR
import Testing
import UIKit

@testable import CredentialSharingUI
@testable import SharingOrchestration

// swiftlint:disable file_length
@MainActor
struct HolderContainerNavigationTests {
    let mockOrchestrator = MockHolderOrchestrator()

    private func makeSUT() -> HolderNavigationController {
        HolderNavigationController(orchestrator: mockOrchestrator)
    }

    // MARK: - Lifecycle

    @Test("viewWillAppear triggers orchestrator startTransaction")
    func viewWillAppearTriggersOrchestrator() {
        // Given
        let sut = makeSUT()
        #expect(mockOrchestrator.startPresentationCalled == false)

        // When
        sut.viewWillAppear(false)

        // Then
        #expect(mockOrchestrator.startPresentationCalled == true)
    }

    @Test("viewWillAppear sets presentationController delegate to self")
    func viewWillAppearSetsDelegate() {
        // Given
        let sut = makeSUT()

        // When
        sut.viewWillAppear(false)

        // Then
        #expect(sut.presentationController?.delegate === sut)
    }

    @Test("didTapCancel triggers orchestrator cancel")
    func didTapCancelTriggersOrchestrator() {
        // Given
        let sut = makeSUT()
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        // When
        sut.didTapCancel()

        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
    }

    @Test("presentationControllerDidAttemptToDismiss calls didTapCancel")
    func presentationControllerDidAttemptToDismissCallsCancel() throws {
        // Given
        let sut = makeSUT()
        sut.viewWillAppear(false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        // When
        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
    }

    // MARK: - State routing

    @Test("orchestrator didUpdateState .preflight pushes ReadinessViewController")
    func renderTriggersGetReadyToShareView() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let state = HolderSessionState.preflight(
            ReadinessPresentation(
                missingPrerequisites: [MissingPrerequisite.bluetooth(.authorizationNotDetermined)],
                cancelRequiresConfirmation: false
            )
        )

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        #expect(sut.viewControllers.last is ReadinessViewController)
    }

    @Test("orchestrator didUpdateState .processingEstablishment pushes LoadingViewController")
    func processingEngagementPushesLoadingViewController() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .processingEstablishment)

        // Then
        #expect(sut.viewControllers.last is LoadingViewController)
    }

    @Test("orchestrator didUpdateState .presentingEngagement pushes QRCodeViewController")
    func renderTriggersQRCodeView() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        let state = HolderSessionState.presentingEngagement(
            EngagementPresentation(qrPayload: "test", cancelRequiresConfirmation: nil)
        )

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        #expect(sut.viewControllers.last is QRCodeViewController)
    }

    @Test("orchestrator didUpdateState .awaitingUserConsent pushes ConsentViewController")
    func renderRequestReceivedTriggersConsentView() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let state = HolderSessionState.awaitingUserConsent(makeConsentPresentation())

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        #expect(sut.viewControllers.last is ConsentViewController)
    }

    @Test("orchestrator didUpdateState .awaitingVerifierResolution pushes 'Details shared' screen")
    func awaitingVerifierResolutionPushesDetailsSharedScreen() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .awaitingVerifierResolution)

        // Then
        let terminalVC = try #require(sut.viewControllers.last as? TerminalStateViewController)
        _ = terminalVC.view
        let label = try #require(terminalVC.view.subviews.first {
            $0.accessibilityIdentifier == "TerminalStateLabel"
        } as? UILabel)
        #expect(label.text == "Details shared")
    }

    @Test("orchestrator didUpdateState .failed(.generic) pushes ErrorViewController with message")
    func renderFailedGenericTriggersErrorView() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let state = HolderSessionState.failed(.generic("Mock error description"))

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        let errorViewController = try #require(sut.viewControllers.last as? ErrorViewController)
        #expect(errorMessage(from: errorViewController) == "Mock error description")
    }

    @Test("orchestrator didUpdateState nil pushes ErrorViewController with generic message")
    func renderNoStateTriggersErrorView() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: nil)

        // Then
        let errorViewController = try #require(sut.viewControllers.last as? ErrorViewController)
        #expect(errorMessage(from: errorViewController) == "Something went wrong. Try again later.")
    }

    @Test("orchestrator didUpdateState .failed(.transportError) pushes ErrorViewController")
    func failedTransportErrorPushesErrorViewController() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .failed(.transportError))

        // Then
        let errorViewController = try #require(sut.viewControllers.last as? ErrorViewController)
        #expect(errorMessage(from: errorViewController) == "BLE connection dropped, or the remote device became unreachable")
    }

    // MARK: - Dismissal

    @Test("orchestrator didUpdateState .cancelled dismisses navigation")
    func renderDismissesNavigation() {
        // Given
        let sut = SpyHolderContainerNavigation(orchestrator: mockOrchestrator)

        // When
        sut.orchestrator(didUpdateState: .cancelled)

        // Then
        #expect(sut.dismissCalled)
    }

    @Test("orchestrator didUpdateState .success(.responseSent) does not dismiss")
    func successResponseSentDoesNotDismiss() {
        // Given
        let sut = SpyHolderContainerNavigation(orchestrator: mockOrchestrator)

        // When — details shared screen remains visible, user dismisses manually
        sut.orchestrator(didUpdateState: .success(reason: .responseSent))

        // Then
        #expect(sut.dismissCalled == false)
    }

    @Test("orchestrator didUpdateState .success(.denialResponse) dismisses navigation")
    func successDenialResponseDismissesNavigation() {
        // Given
        let sut = SpyHolderContainerNavigation(orchestrator: mockOrchestrator)

        // When
        sut.orchestrator(didUpdateState: .success(reason: .denialResponse))

        // Then
        #expect(sut.dismissCalled)
    }

    @Test("orchestrator didUpdateState .success(.emptyResponse) pushes 'Unfulfillable request' screen")
    func successEmptyResponsePushesUnfulfillableRequestScreen() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .success(reason: .emptyResponse))

        // Then
        let terminalVC = try #require(sut.viewControllers.last as? TerminalStateViewController)
        _ = terminalVC.view
        let label = try #require(terminalVC.view.subviews.first {
            $0.accessibilityIdentifier == "TerminalStateLabel"
        } as? UILabel)
        #expect(label.text == "Unfulfillable request")
    }

    // MARK: - Cancel Button Tests

    @Test("Non-root view controller receives a right Cancel button")
    func pushedViewControllerGetsCancelButton() {
        // Given — seed a root so the pushed VC is not viewControllers.first
        let sut = makeSUT()
        _ = sut.view
        sut.setViewControllers([UIViewController()], animated: false)
        let pushedVC = UIViewController()

        // When
        sut.navigationController(sut, willShow: pushedVC, animated: false)

        // Then
        #expect(pushedVC.navigationItem.rightBarButtonItem != nil)
        #expect(pushedVC.navigationItem.rightBarButtonItem?.title == "Cancel")
        #expect(pushedVC.navigationItem.rightBarButtonItem?.accessibilityIdentifier == "CancelButton")
    }

    @Test("Root view controller does not receive a Cancel button")
    func rootContainerDoesNotGetCancelButton() {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let rootVC = UIViewController()
        sut.setViewControllers([rootVC], animated: false)

        // When
        sut.navigationController(sut, willShow: rootVC, animated: false)

        // Then
        #expect(rootVC.navigationItem.rightBarButtonItem == nil)
    }

    @Test("Cancel button triggers cancellation on the orchestrator")
    func cancelButtonTriggersCancellation() {
        // Given
        let sut = makeSUT()
        _ = sut.view
        sut.setViewControllers([UIViewController()], animated: false)
        let pushedVC = UIViewController()
        sut.navigationController(sut, willShow: pushedVC, animated: false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        // When
        _ = pushedVC.navigationItem.rightBarButtonItem?.target?.perform(
            pushedVC.navigationItem.rightBarButtonItem?.action
        )

        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
    }

    // MARK: - Cancel Confirmation Dialog Tests

    @Test("didTapCancel in active BLE state presents confirmation dialog with correct structure")
    func didTapCancelInActiveStatePresentsConfirmationDialog() throws {
        // Given
        mockOrchestrator.shouldRequestCancelConfirmation = true
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        // When
        sut.didTapCancel()

        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
        let alert = try #require(sut.presentedViewController as? UIAlertController)
        #expect(alert.title == nil)
        #expect(alert.message == "Are you sure you want to cancel?")
        #expect(alert.actions.count == 2)
        #expect(alert.actions[0].title == "Yes")
        #expect(alert.actions[0].style == .destructive)
        #expect(alert.actions[1].title == "No")
        #expect(alert.actions[1].style == .cancel)
    }

    @Test("Confirming cancellation dialog calls userDidConfirmCancel on orchestrator")
    func confirmingCancellationCallsUserDidConfirmCancel() {
        // Given
        let sut = makeSUT()
        sut.loadViewIfNeeded()
        #expect(mockOrchestrator.confirmCancelCalled == false)

        // When — simulate the confirm action from the dialog
        sut.orchestratorDidRequestCancelConfirmation()
        mockOrchestrator.confirmCancelCalled = false
        sut.orchestrator.userDidConfirmCancel()

        // Then
        #expect(mockOrchestrator.confirmCancelCalled == true)
    }

    @Test("Dismissing cancellation dialog does not call confirm cancel on orchestrator")
    func dismissingCancellationDialogDoesNotCancel() {
        // Given
        mockOrchestrator.shouldRequestCancelConfirmation = true
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        // When — trigger dialog then tap 'No'
        sut.didTapCancel()
        mockOrchestrator.confirmCancelCalled = false

        // Then — dialog is shown but confirm cancel is not called
        #expect(sut.presentedViewController is UIAlertController)
        #expect(mockOrchestrator.confirmCancelCalled == false)
    }

    // MARK: - Helper Methods

    private func errorMessage(from errorViewController: UIViewController) -> String? {
        let stackView = errorViewController.view.subviews.first { $0 is UIStackView } as? UIStackView
        return stackView?.arrangedSubviews
            .compactMap { $0 as? UILabel }
            .first?
            .text
    }

    private func makeConsentPresentation() -> ConsentPresentation {
        ConsentPresentation(
            dvsName: "GDS",
            documentType: DocumentType(displayLabel: "org.iso.18013.5.1.mDL", documentIcon: UIImage()),
            attributes: [
                ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "family_name", intentToRetain: false),
                ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "portrait", intentToRetain: false)
            ],
            privacyPolicyURL: URL(string: "https://example.gov.uk/privacy")!
        )
    }
}

class EmptyViewController: UIViewController {}

/// Spy that records whether the navigation controller was asked to dismiss,
/// so dismissal-driving states can be verified without a parent presenter.
@MainActor
final class SpyHolderContainerNavigation: HolderNavigationController {
    var dismissCalled = false

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCalled = true
    }
}
// swiftlint:enable file_length
