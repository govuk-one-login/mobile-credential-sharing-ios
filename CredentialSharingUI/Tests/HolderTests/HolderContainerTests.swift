import SharingCryptoService
import SharingOrchestration
import SharingPrerequisiteGate
import SwiftCBOR
import Testing
import UIKit

@testable import CredentialSharingUI

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
        let qrCode = try QRGenerator(data: Data()).generateQRCode()
        let state = HolderSessionState.presentingEngagement(qrCode: qrCode)

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

    @Test("Legacy UIKit screens receive a container Cancel button")
    func legacyScreenGetsCancelButton() {
        // Given — a non-GDS, non-terminal screen relies on the container to
        // provide the Cancel button.
        let sut = makeSUT()
        _ = sut.view
        let legacyVC = UIViewController()

        // When
        sut.navigationController(sut, willShow: legacyVC, animated: false)

        // Then
        #expect(legacyVC.navigationItem.rightBarButtonItem != nil)
        #expect(legacyVC.navigationItem.rightBarButtonItem?.title == "Cancel")
        #expect(legacyVC.navigationItem.rightBarButtonItem?.accessibilityIdentifier == "CancelButton")
    }

    @Test("GDS screens do not receive a container Cancel button")
    func gdsScreenDoesNotGetCancelButton() {
        // Given — a GDS screen configures its own Cancel bar button, so the
        // container must not add a second one.
        let sut = makeSUT()
        _ = sut.view
        let gdsScreen = ReadinessViewController(
            presentation: ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.statePoweredOff)],
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            onCancel: {}
        )
        sut.setViewControllers([gdsScreen], animated: false)

        // When
        sut.navigationController(sut, willShow: gdsScreen, animated: false)

        // Then
        #expect(gdsScreen.navigationItem.rightBarButtonItem == nil)
    }

    @Test("Cancel button triggers cancellation on the orchestrator")
    func cancelButtonTriggersCancellation() {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let legacyVC = UIViewController()
        sut.navigationController(sut, willShow: legacyVC, animated: false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        // When
        _ = legacyVC.navigationItem.rightBarButtonItem?.target?.perform(
            legacyVC.navigationItem.rightBarButtonItem?.action
        )

        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
    }

    // MARK: - Cancel Confirmation Dialog Tests

    @Test("Confirmation dialog presents a destructive Yes action and a cancel No action")
    func confirmationDialogIsCorrectlyWired() throws {
        // Given
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        // When — a screen requiring confirmation surfaces the dialog
        sut.presentCancelConfirmation()

        // Then — a two-action alert is presented; 'Yes' is destructive (drives
        // cancellation via userDidTapCancel), 'No' is the cancel style.
        let alert = try #require(sut.presentedViewController as? UIAlertController)
        #expect(alert.title == nil)
        #expect(alert.message == "Are you sure you want to cancel?")
        #expect(alert.actions.count == 2)
        let confirmAction = try #require(alert.actions.first { $0.title == "Yes" })
        #expect(confirmAction.style == .destructive)
        let dismissAction = try #require(alert.actions.first { $0.title == "No" })
        #expect(dismissAction.style == .cancel)
    }

    @Test("Presenting the cancellation dialog alone does not cancel the session")
    func dismissingCancellationDialogDoesNotCancel() {
        // Given
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        // When — a screen requiring confirmation surfaces the dialog
        sut.presentCancelConfirmation()

        // Then — presenting the dialog alone must not cancel the session;
        // cancellation only happens when the user taps 'Yes'.
        #expect(sut.presentedViewController is UIAlertController)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
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
