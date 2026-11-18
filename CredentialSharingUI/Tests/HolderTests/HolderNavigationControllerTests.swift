import CredentialSharingTestFixtures
import DesignSystem
import GDSCommon
import SharingCryptoService
import SharingPrerequisiteGate
import SwiftCBOR
import Testing
import UIKit

@testable import CredentialSharingUI
@testable import SharingOrchestration

// swiftlint:disable file_length
@MainActor
// swiftlint:disable:next type_body_length
struct HolderNavigationControllerTests {
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

    @Test("presentationControllerDidAttemptToDismiss routes through handleCancel, not a silent cancel")
    func presentationControllerDidAttemptToDismissRoutesThroughHandleCancel() throws {
        // Given — no screen configured yet, so no cancel requirement captured
        let sut = makeSUT()
        sut.viewWillAppear(false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        // When the user attempts to swipe the sheet down
        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        // Then — swipe no longer bypasses the confirmation checks; with no
        // presentation configured it is a no-op rather than a silent cancel.
        // Per-screen routing is covered by the Swipe-to-dismiss tests below.
        #expect(mockOrchestrator.cancelPresentationCalled == false)
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
    
    
    @Test("orchestrator didUpdateState .preflight with Bluetooth .statePoweredOff pushes ReadinessViewController with the BluetoothPoweredOffViewModel")
    func renderPoweredOffPushesTurnOnBluetoothViewModel() async throws {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let state = HolderSessionState.preflight(
            ReadinessPresentation(
                missingPrerequisites: [MissingPrerequisite.bluetooth(.statePoweredOff)],
                cancelRequiresConfirmation: false
            )
        )

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        
        let readiness = try #require(
            sut.viewControllers
                .compactMap { $0 as? ReadinessViewController }
                .first
        )
        #expect(sut.viewControllers.last is ReadinessViewController)
        #expect(readiness.viewModel is BluetoothPoweredOffViewModel)
    }

    @Test("orchestrator didUpdateState .processingEstablishment pushes ProgressViewController")
    func processingEngagementPushesProgressViewController() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .processingEstablishment(ProgressPresentation(phase: .processingRequest, cancelRequiresConfirmation: true)))

        // Then
        #expect(sut.viewControllers.last is ProgressViewController)
    }

    @Test("orchestrator didUpdateState .processingResponse pushes ProgressViewController")
    func processingResponsePushesProgressViewController() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .processingResponse(ProgressPresentation(phase: .sendingResponse, cancelRequiresConfirmation: nil)))

        // Then
        #expect(sut.viewControllers.last is ProgressViewController)
    }

    @Test("orchestrator didUpdateState .presentingEngagement pushes QRCodeViewController")
    func renderTriggersQRCodeView() {
        // Given
        let sut = makeSUT()
        _ = sut.view

        let state = HolderSessionState.presentingEngagement(
            EngagementPresentation(qrPayload: "test", cancelRequiresConfirmation: nil)
        )

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        #expect(sut.viewControllers.last is EngagementViewController)
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

    @Test("orchestrator didUpdateState .awaitingVerifierResolution does not push a resolution screen")
    func awaitingVerifierResolutionDoesNotPushResolutionScreen() {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When — a transient waiting state; the Details-shared screen is driven
        // only by the terminal .success(.detailsShared) presentation.
        sut.orchestrator(didUpdateState: .awaitingVerifierResolution)

        // Then — no resolution screen is pushed for this state.
        #expect(sut.viewControllers.last is ResolutionViewController == false)
    }

    @Test("orchestrator didUpdateState .failed(.generic) pushes the generic error screen")
    func renderFailedGenericPushesGenericErrorScreen() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let state = HolderSessionState.failed(.generic("Mock error description"))

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        let errorScreen = try #require(sut.viewControllers.last as? GDSErrorScreen)
        #expect(errorScreen.viewModel is ResolutionFailureViewModel)
        #expect(sut.viewControllers.last is ErrorViewController == false)
    }

    @Test("orchestrator didUpdateState .failed(.unknown) pushes the generic error screen")
    func renderFailedUnknownPushesGenericErrorScreen() {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .failed(.unknown))

        // Then
        #expect(sut.viewControllers.last is GDSErrorScreen)
    }

    @Test("Generic error screen reports its error description as the analytics reason")
    func genericErrorScreenTracksErrorDescription() throws {
        // Given
        let analyticsService = MockSharingAnalyticsService()
        let sut = HolderNavigationController(
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService
        )
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .failed(.generic("Mock error description")))
        let errorScreen = try #require(sut.viewControllers.last as? GDSErrorScreen)
        let viewModel = try #require(errorScreen.viewModel as? ResolutionFailureViewModel)
        viewModel.didAppear()

        // Then
        #expect(analyticsService.trackedScreens == [.genericError])
        #expect(analyticsService.trackedErrorDescriptions == ["Mock error description"])
    }

    @Test(
        "Categories without their own screen yet fall back to the generic error screen",
        arguments: [
            FailureCategory.connectionInterrupted,
            .requestCannotBeUsed,
            .credentialUnavailable,
            .secureSharingCouldNotComplete,
            .unexpectedProblem
        ]
    )
    func unmappedCategoriesFallBackToGenericErrorScreen(category: FailureCategory) {
        // Given
        let sut = makeSUT()
        _ = sut.view
        let state = HolderSessionState.failed(
            presentation: ResolutionPresentation(
                result: .failed(category, errorDescription: "Some description")
            )
        )

        // When
        sut.orchestrator(didUpdateState: state)

        // Then
        #expect(sut.viewControllers.last is GDSErrorScreen)
    }

    @Test("orchestrator didUpdateState .failed with no result pushes the legacy ErrorViewController")
    func failedWithoutResultPushesLegacyErrorScreen() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .failed(presentation: ResolutionPresentation(result: nil)))

        // Then
        let errorViewController = try #require(sut.viewControllers.last as? ErrorViewController)
        #expect(errorMessage(from: errorViewController) == "Something went wrong. Try again later.")
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

    @Test(
        "Denied Bluetooth and camera failures keep the legacy screen with the Open Settings button",
        arguments: [
            SessionError.unrecoverablePrerequisite(.bluetooth(.authorizationDenied)),
            SessionError.unrecoverablePrerequisite(.camera(.authorizationDenied))
        ]
    )
    func deniedPrerequisiteKeepsLegacyScreenWithSettingsCTA(error: SessionError) throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .failed(error))

        // Then
        let errorViewController = try #require(sut.viewControllers.last as? ErrorViewController)
        _ = errorViewController.view
        #expect(sut.viewControllers.last is GDSErrorScreen == false)
        #expect(containsOpenSettingsButton(in: errorViewController.view))
    }

    @Test("Peer termination while 'Details shared' is showing keeps the current screen")
    func peerTerminationOverDetailsSharedKeepsCurrentScreen() throws {
        // Given the Details shared screen is on top
        let sut = makeSUT()
        _ = sut.view
        sut.orchestrator(didUpdateState: .success(presentation: ResolutionPresentation(result: .detailsShared)))
        let detailsShared = try #require(sut.viewControllers.last as? ResolutionViewController)

        // When the peer terminates
        sut.orchestrator(didUpdateState: .failed(.peerTermination))

        // Then the screen is unchanged
        #expect(sut.viewControllers.last === detailsShared)
    }

    @Test("Peer termination before the response was sent shows the legacy error screen")
    func peerTerminationElsewhereShowsLegacyErrorScreen() {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .failed(.peerTermination))

        // Then
        #expect(sut.viewControllers.last is ErrorViewController)
    }

    // MARK: - Dismissal

    @Test("orchestrator didUpdateState .cancelled dismisses navigation")
    func renderDismissesNavigation() {
        // Given
        let sut = SpyHolderNavigationController(orchestrator: mockOrchestrator)

        // When
        sut.orchestrator(didUpdateState: .cancelled)

        // Then
        #expect(sut.dismissCalled)
    }

    @Test("orchestrator didUpdateState .success(.responseSent) does not dismiss")
    func successResponseSentDoesNotDismiss() {
        // Given
        let sut = SpyHolderNavigationController(orchestrator: mockOrchestrator)

        // When — details shared screen remains visible, user dismisses manually
        sut.orchestrator(didUpdateState: .success(presentation: ResolutionPresentation(result: .detailsShared)))

        // Then
        #expect(sut.dismissCalled == false)
    }

    @Test("orchestrator didUpdateState .success(.responseSent) pushes DetailsShared when not already shown")
    func successResponseSentPushesDetailsSharedScreen() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .success(presentation: ResolutionPresentation(result: .detailsShared)))

        // Then
        let terminalVC = try #require(sut.viewControllers.last as? ResolutionViewController)
        #expect(terminalVC.viewModel is DetailsSharedViewModel)
    }

    @Test("orchestrator didUpdateState .success(.detailsShared) pushes a single DetailsShared screen")
    func successDetailsSharedPushesSingleScreen() throws {
        // Given — a transient waiting state that shows no screen
        let sut = makeSUT()
        _ = sut.view
        sut.orchestrator(didUpdateState: .awaitingVerifierResolution)
        let countBeforeSuccess = sut.viewControllers.count

        // When — the terminal success presentation follows
        sut.orchestrator(didUpdateState: .success(presentation: ResolutionPresentation(result: .detailsShared)))

        // Then — exactly one resolution screen is pushed, hosting DetailsShared
        #expect(sut.viewControllers.count == countBeforeSuccess + 1)
        let terminalVC = try #require(sut.viewControllers.last as? ResolutionViewController)
        #expect(terminalVC.viewModel is DetailsSharedViewModel)
    }

    @Test("orchestratorDidFinish dismisses the navigation")
    func orchestratorDidFinishDismissesNavigation() {
        // Given
        let sut = SpyHolderNavigationController(orchestrator: mockOrchestrator)

        // When — the orchestrator reports the terminal journey finished
        // (e.g. "Go back to documents" on the Details Shared screen).
        sut.orchestratorDidFinish()

        // Then
        #expect(sut.dismissCalled)
    }

    @Test("orchestrator didUpdateState .success(.denialResponse) dismisses navigation")
    func successDenialResponseDismissesNavigation() {
        // Given
        let sut = SpyHolderNavigationController(orchestrator: mockOrchestrator)

        // When
        sut.orchestrator(didUpdateState: .success(presentation: ResolutionPresentation(result: nil)))

        // Then
        #expect(sut.dismissCalled)
    }

    @Test("orchestrator didUpdateState .success(.emptyResponse) pushes 'Unfulfillable request' screen")
    func successEmptyResponsePushesUnfulfillableRequestScreen() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When
        sut.orchestrator(didUpdateState: .success(presentation: ResolutionPresentation(result: .unfulfillableRequest)))

        // Then
        let terminalVC = try #require(sut.viewControllers.last as? ResolutionViewController)
        let viewModel = try #require(terminalVC.viewModel as? ResolutionViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "ResolutionStateLabel")
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
        // Given — a no-confirmation screen is configured (so the container has
        // captured cancelRequiresConfirmation == false), and a legacy screen that
        // receives the container-provided Cancel button.
        let sut = makeSUT()
        _ = sut.view
        renderReadiness(on: sut, requiresConfirmation: false)
        let legacyVC = UIViewController()
        sut.navigationController(sut, willShow: legacyVC, animated: false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        // When
        _ = legacyVC.navigationItem.rightBarButtonItem?.target?.perform(
            legacyVC.navigationItem.rightBarButtonItem?.action
        )

        // Then — the legacy Cancel button now routes through handleCancel, which
        // cancels directly for a no-confirmation screen.
        #expect(mockOrchestrator.cancelPresentationCalled == true)
    }

    @Test("Cancel button on a confirmation-required screen presents the dialog")
    func cancelButtonRequiringConfirmationPresentsDialog() {
        // Given — a confirmation-required screen is configured, plus a legacy
        // screen that receives the container-provided Cancel button.
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        renderReadiness(on: sut, requiresConfirmation: true)
        let legacyVC = UIViewController()
        sut.navigationController(sut, willShow: legacyVC, animated: false)

        // When
        _ = legacyVC.navigationItem.rightBarButtonItem?.target?.perform(
            legacyVC.navigationItem.rightBarButtonItem?.action
        )

        // Then — routes through handleCancel, surfacing the confirmation alert
        // rather than cancelling directly.
        #expect(sut.presentedViewController is UIAlertController)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
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

    // MARK: - State updates while the cancel confirmation is showing

    /// Renders the confirmation-required progress screen and routes a Cancel tap so
    /// the container enters its "confirmation showing" state.
    ///
    /// Deliberately not hosted in a window: with no window the alert presentation
    /// is skipped, which keeps UIKit's animated present transition from deferring
    /// the `setViewControllers` calls these tests assert on. The deferral logic
    /// under test lives in the container, not the alert.
    private func enterCancelConfirmationOverProgress(on sut: HolderNavigationController) {
        sut.loadViewIfNeeded()
        sut.orchestrator(didUpdateState: .processingEstablishment(
            ProgressPresentation(phase: .processingRequest, cancelRequiresConfirmation: true)
        ))
        sut.handleCancel()
    }

    @Test("State update while the cancel dialog is showing does not replace the screen")
    func stateUpdateWhileCancelDialogShowingIsDeferred() {
        // Given the cancel dialog is showing over the progress screen
        let sut = makeSUT()
        enterCancelConfirmationOverProgress(on: sut)

        // When the orchestrator advances behind the dialog
        sut.orchestrator(didUpdateState: .awaitingUserConsent(makeConsentPresentation()))

        // Then the screen underneath is not swapped
        #expect(sut.viewControllers.last is ProgressViewController)
    }

    @Test("Tapping No resumes the flow by rendering the deferred state")
    func tappingNoRendersDeferredState() {
        // Given a state update was deferred behind the cancel dialog
        let sut = makeSUT()
        enterCancelConfirmationOverProgress(on: sut)
        sut.orchestrator(didUpdateState: .awaitingUserConsent(makeConsentPresentation()))

        // When the user taps No
        sut.cancelConfirmationDismissed()

        // Then the flow resumes on the consent screen and the session is not cancelled
        #expect(sut.viewControllers.last is ConsentViewController)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Tapping No with no deferred state leaves the current screen in place")
    func tappingNoWithNothingDeferredKeepsScreen() {
        // Given the cancel dialog is showing and nothing has changed
        let sut = makeSUT()
        enterCancelConfirmationOverProgress(on: sut)

        // When the user taps No
        sut.cancelConfirmationDismissed()

        // Then the progress screen remains and the session is not cancelled
        #expect(sut.viewControllers.last is ProgressViewController)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Tapping Yes with an active deferred state cancels without rendering it")
    func tappingYesWithActiveDeferredStateCancels() {
        // Given a non-terminal state was deferred behind the cancel dialog
        let sut = makeSUT()
        enterCancelConfirmationOverProgress(on: sut)
        sut.orchestrator(didUpdateState: .awaitingUserConsent(makeConsentPresentation()))

        // When the user taps Yes
        sut.cancelConfirmationConfirmed()

        // Then the session is cancelled and the deferred screen is never shown
        #expect(mockOrchestrator.cancelPresentationCalled == true)
        #expect(!(sut.viewControllers.last is ConsentViewController))
    }

    @Test("Tapping Yes after the session already failed shows the error instead of cancelling")
    func tappingYesAfterSessionFailedShowsError() {
        // Given the session failed while the cancel dialog was showing
        let sut = makeSUT()
        enterCancelConfirmationOverProgress(on: sut)
        sut.orchestrator(didUpdateState: .failed(.generic("Something went wrong")))
        #expect(sut.viewControllers.last is ProgressViewController)

        // When the user taps Yes
        sut.cancelConfirmationConfirmed()

        // Then there is nothing left to cancel, so the error screen is shown
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(sut.viewControllers.last is GDSErrorScreen)
    }

    @Test("State updates render immediately once the cancel dialog has been answered")
    func stateUpdatesRenderNormallyAfterDialogAnswered() {
        // Given the dialog was answered with No
        let sut = makeSUT()
        enterCancelConfirmationOverProgress(on: sut)
        sut.cancelConfirmationDismissed()

        // When a later state update arrives
        sut.orchestrator(didUpdateState: .awaitingUserConsent(makeConsentPresentation()))

        // Then it is rendered straight away
        #expect(sut.viewControllers.last is ConsentViewController)
    }

    // MARK: - handleCancel Routing Tests

    /// Renders the readiness screen so the container captures
    /// `cancelRequiresConfirmation` from its presentation, mirroring production.
    private func renderReadiness(on sut: HolderNavigationController, requiresConfirmation: Bool) {
        sut.orchestrator(didUpdateState: .preflight(
            ReadinessPresentation(
                missingPrerequisites: [.bluetooth(.statePoweredOff)],
                cancelRequiresConfirmation: requiresConfirmation
            )
        ))
    }

    @Test("handleCancel on a confirmation-required screen presents the dialog and does not cancel")
    func handleCancelRequiringConfirmationPresentsDialog() {
        // Given a presented screen whose presentation requires confirmation
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        renderReadiness(on: sut, requiresConfirmation: true)

        // When
        sut.handleCancel()

        // Then — the confirmation alert is surfaced and the session is NOT
        // cancelled until the user confirms.
        #expect(sut.presentedViewController is UIAlertController)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("handleCancel on a no-confirmation screen cancels directly without a dialog")
    func handleCancelNotRequiringConfirmationCancelsDirectly() {
        // Given a presented screen whose presentation does not require confirmation
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        renderReadiness(on: sut, requiresConfirmation: false)

        // When
        sut.handleCancel()

        // Then — cancellation is driven immediately, no confirmation alert.
        #expect(mockOrchestrator.cancelPresentationCalled == true)
        #expect(sut.presentedViewController == nil)
    }

    @Test("handleCancel before any screen is configured is a no-op")
    func handleCancelBeforeConfigurationIsNoOp() {
        // Given a container with no presentation configured yet
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        // When
        sut.handleCancel()

        // Then — nil captured flag means neither cancel nor dialog.
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(sut.presentedViewController == nil)
    }

    // MARK: - Swipe-to-dismiss Tests

    @Test("Swipe attempt on a confirmation-required GDS screen is a no-op")
    func swipeAttemptOnGDSConfirmationScreenIsNoOp() throws {
        // Given a confirmation-required GDS readiness screen
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        renderReadiness(on: sut, requiresConfirmation: true)

        // When the user attempts to swipe the sheet down
        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        // Then — no cancel, no dialog; cancel only via the screen's own button.
        #expect(sut.presentedViewController == nil)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Swipe attempt on a no-confirmation GDS screen is a no-op")
    func swipeAttemptOnGDSNoConfirmationScreenIsNoOp() throws {
        // Given a no-confirmation GDS readiness screen
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        renderReadiness(on: sut, requiresConfirmation: false)

        // When the user attempts to swipe the sheet down
        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        // Then — the swipe does not cancel the session.
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(sut.presentedViewController == nil)
    }

    @Test("Swipe attempt on the confirmation-required Progress screen is a no-op")
    func swipeAttemptOnProgressConfirmationScreenIsNoOp() throws {
        // Given — .processingEstablishment shows the GDS ProgressViewController
        // and captures cancelRequiresConfirmation == true.
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        sut.orchestrator(didUpdateState: .processingEstablishment(ProgressPresentation(phase: .processingRequest, cancelRequiresConfirmation: true)))
        let progress = try #require(sut.viewControllers.last as? ProgressViewController)
        #expect(progress is GDSScreen)

        // When the user attempts to swipe the sheet down
        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        // Then — the Progress screen is a GDS screen, so the swipe is blocked:
        // no confirmation dialog and no cancellation. Cancel is only reachable
        // via the screen's own Cancel button, which surfaces the dialog.
        #expect(sut.presentedViewController == nil)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Cancelling the Progress screen surfaces the confirmation dialog")
    func cancelOnProgressScreenPresentsConfirmationDialog() throws {
        // Given — .processingEstablishment shows the Progress screen, which now
        // requires confirmation before cancelling (per design).
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        sut.orchestrator(didUpdateState: .processingEstablishment(ProgressPresentation(phase: .processingRequest, cancelRequiresConfirmation: true)))
        #expect(sut.viewControllers.last is ProgressViewController)

        // When the user cancels (the Progress screen's Cancel button routes
        // through the container's handleCancel)
        sut.handleCancel()

        // Then — the confirmation dialog is surfaced and the session is NOT
        // cancelled until the user confirms.
        #expect(sut.presentedViewController is UIAlertController)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test("Swipe attempt on the Consent screen presents the confirmation dialog")
    func swipeAttemptOnConsentScreenPresentsDialog() throws {
        // Given the Consent screen
        let sut = makeSUT()
        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()
        sut.viewWillAppear(false)
        sut.orchestrator(didUpdateState: .awaitingUserConsent(makeConsentPresentation()))
        let consent = try #require(sut.viewControllers.last as? ConsentViewController)
        sut.navigationController(sut, willShow: consent, animated: false)
        #expect(sut.isModalInPresentation == true)

        // When the user attempts to swipe the sheet down
        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        // Then — the swipe is blocked and routes through handleCancel, surfacing
        // the confirmation dialog rather than dismissing.
        #expect(sut.presentedViewController is UIAlertController)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
    }

    @Test(
        "GDS screens are not swipe-to-dismissable",
        arguments: [
            HolderSessionState.preflight(
                ReadinessPresentation(
                    missingPrerequisites: [.bluetooth(.statePoweredOff)],
                    cancelRequiresConfirmation: false
                )
            ),
            HolderSessionState.preflight(
                ReadinessPresentation(
                    missingPrerequisites: [.bluetooth(.authorizationNotDetermined)],
                    cancelRequiresConfirmation: false
                )
            ),
            HolderSessionState.success(presentation: ResolutionPresentation(result: .detailsShared)),
            HolderSessionState.success(presentation: ResolutionPresentation(result: .unfulfillableRequest))
        ]
    )
    func gdsScreenIsNotSwipeDismissable(state: HolderSessionState) throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When — a GDS screen (readiness or a resolution screen) is shown
        sut.orchestrator(didUpdateState: state)
        let gdsScreen = try #require(sut.viewControllers.last)
        #expect(gdsScreen is GDSScreen)
        sut.navigationController(sut, willShow: gdsScreen, animated: false)

        // Then — swipe-to-dismiss is blocked
        #expect(sut.isModalInPresentation == true)
    }

    @Test(
        "Legacy error screens are swipe-to-dismissable",
        arguments: [
            SessionError.transportError,
            SessionError.invalidDeviceRequest,
            SessionError.peerTermination
        ]
    )
    func legacyErrorScreenIsSwipeDismissable(error: SessionError) throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When — a legacy error screen is shown
        sut.orchestrator(didUpdateState: .failed(error))
        let errorVC = try #require(sut.viewControllers.last as? ErrorViewController)
        sut.navigationController(sut, willShow: errorVC, animated: false)

        // Then — swipe-to-dismiss stays enabled
        #expect(sut.isModalInPresentation == false)
    }

    @Test("Generic error screen is not swipe-to-dismissable and has no legacy Cancel button")
    func genericErrorScreenIsNotSwipeDismissableAndHasNoCancelButton() throws {
        // Given
        let sut = makeSUT()
        _ = sut.view

        // When — the generic error screen is shown
        sut.orchestrator(didUpdateState: .failed(.generic("Something went wrong")))
        let errorScreen = try #require(sut.viewControllers.last as? GDSErrorScreen)
        sut.navigationController(sut, willShow: errorScreen, animated: false)

        // Then — swipe is blocked and the container adds no Cancel bar button
        #expect(sut.isModalInPresentation == true)
        #expect(errorScreen.navigationItem.rightBarButtonItem == nil)
    }

    @Test("Swiping down on the generic error screen does not cancel the session")
    func swipeOnGenericErrorScreenIsNoOp() throws {
        // Given
        let sut = makeSUT()
        sut.viewWillAppear(false)
        sut.orchestrator(didUpdateState: .failed(.generic("Something went wrong")))
        #expect(sut.viewControllers.last is GDSErrorScreen)

        // When the user attempts to swipe the sheet down
        sut.presentationControllerDidAttemptToDismiss(try #require(sut.presentationController))

        // Then — no cancel is routed and no confirmation is presented
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(sut.presentedViewController == nil)
    }

    // MARK: - Helper Methods

    private func containsOpenSettingsButton(in view: UIView) -> Bool {
        if view.accessibilityIdentifier == ErrorViewController.openSettingsButtonIdentifier {
            return true
        }
        return view.subviews.contains { containsOpenSettingsButton(in: $0) }
    }

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
                ConsentAttribute(namespace: "org.iso.18013.5.1", identifier: "family_name", intentToRetain: false),
                ConsentAttribute(namespace: "org.iso.18013.5.1", identifier: "portrait", intentToRetain: false)
            ],
            privacyPolicyURL: URL(string: "https://example.gov.uk/privacy")!
        )
    }
}

class EmptyViewController: UIViewController {}

/// Spy that records whether the navigation controller was asked to dismiss,
/// so dismissal-driving states can be verified without a parent presenter.
@MainActor
final class SpyHolderNavigationController: HolderNavigationController {
    var dismissCalled = false

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCalled = true
    }
}

// swiftlint:enable file_length
