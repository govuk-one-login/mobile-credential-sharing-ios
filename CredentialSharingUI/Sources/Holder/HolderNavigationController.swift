import DesignSystem
import Logging // GDS Analytics package
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
protocol ConsentRetryDelegate: AnyObject {
    func consentRetryAvailable()
}

@MainActor
class HolderNavigationController: UINavigationController {
    var orchestrator: HolderOrchestratorProtocol
    private let analyticsService: AnalyticsService?
    private weak var retryDelegate: ConsentRetryDelegate?

    /// Confirmation requirement of the currently presented screen. Captured when
    /// each presentation is configured so cancel routing (tap or swipe-to-dismiss)
    /// can consult it without the caller supplying the flag. `nil` until the first
    /// screen is configured, in which case cancellation is a no-op.
    private var cancelRequiresConfirmation: Bool?

    init(orchestrator: HolderOrchestratorProtocol, analyticsService: AnalyticsService? = nil) {
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
        self.delegate = self
        self.isModalInPresentation = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Each time a new presentation is started, the presentationController delegate must be set
        self.presentationController?.delegate = self
        orchestrator.startTransaction()
    }
}

// MARK: - HolderOrchestratorDelegate
extension HolderNavigationController: @MainActor HolderOrchestratorDelegate {
    func orchestrator(didUpdateState state: HolderSessionState?) {
        guard let state else {
            navigateToErrorView(
                error: .generic("Something went wrong. Try again later.")
            )
            return
        }
        
        switch state {
        case .notStarted,
             .readyToPresent,
             .processingResponse,
             .terminatingSession,
             .expired:
            break
        case .preflight(let presentation):
            renderGetReadyToShareUI(for: presentation)
        case .presentingEngagement(let presentation):
            renderQRCodeUI(with: presentation)
        case .processingEstablishment:
            navigateTo(LoadingViewController())
        case .awaitingUserConsent(let presentation):
            renderConsentUI(for: presentation)
        case .awaitingVerifierResolution:
            Logger.log("Navigating to details shared screen")
            navigateTo(TerminalStateViewController(message: "Details shared"))
        case .success(let reason):
            handleSuccess(reason)
        case .cancelled:
            dismiss(animated: true)
        case .failed(let error):
            handleFailure(error)
        }
    }

    private func handleSuccess(_ reason: SuccessReason) {
        switch reason {
        case .responseSent:
            break
        case .denialResponse:
            dismiss(animated: true)
        case .emptyResponse:
            Logger.log("Navigating to unfulfillable request screen")
            navigateTo(TerminalStateViewController(message: "Unfulfillable request"))
        }
    }

    private func handleFailure(_ error: SessionError) {
        switch error {
        case .transportError:
            navigateToErrorView(error: error)
        case .peerTermination
            where topViewController is TerminalStateViewController:
            // Peer terminated while 'details shared' screen is visible — remain on current screen
            break
        default:
            Logger.log("Failed with error: \(error)", level: .error)
            navigateToErrorView(error: error)
        }
    }
    
    /// Routes a Cancel request (button tap or swipe-to-dismiss): screens whose
    /// presentation requires confirmation surface the confirmation alert; all
    /// others cancel immediately. Reads `cancelRequiresConfirmation`, captured
    /// when the current presentation was configured. A `nil` flag (no presentation
    /// configured yet) is a no-op.
    func handleCancel() {
        guard let cancelRequiresConfirmation else { return }

        if cancelRequiresConfirmation {
            presentCancelConfirmation()
        } else {
            orchestrator.userDidTapCancel()
        }
    }

    // TODO: DCMAW-23709 - Update the UI of the dialog here in DCMAW-23709
    func presentCancelConfirmation() {
        Logger.log("Cancel confirmation dialog presented")
        let alert = UIAlertController(
            title: nil,
            message: "Are you sure you want to cancel?",
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            Logger.log("Cancel confirmation confirmed — cancelling session")
            self?.orchestrator.userDidTapCancel()
        }

        let dismissAction = UIAlertAction(title: "No", style: .cancel) { _ in
            Logger.log("Cancel confirmation dismissed — session remains active")
        }

        alert.addAction(confirmAction)
        alert.addAction(dismissAction)

        present(alert, animated: true)
    }

    func orchestratorFailedRecoverably() {
        retryDelegate?.consentRetryAvailable()
    }

    private func navigateToErrorView(error: SessionError) {
        let errorViewController = ErrorViewController(error: error, analyticsService: analyticsService)
        navigateTo(errorViewController)
    }

    private func renderGetReadyToShareUI(for presentation: ReadinessPresentation) {
        cancelRequiresConfirmation = presentation.cancelRequiresConfirmation
        navigateTo(
            ReadinessViewController(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: { [weak self] in
                    self?.handleCancel()
                }
            )
        )
    }

    private func renderConsentUI(for presentation: ConsentPresentation) {
        // ConsentPresentation does not yet carry a cancelRequiresConfirmation flag,
        // so preserve the existing behaviour of cancelling without confirmation.
        // TODO: DCMAW-23705 drive this from the presentation once the flag exists.
        cancelRequiresConfirmation = false
        let consentViewController = ConsentViewController(
            presentation: presentation,
            orchestrator: orchestrator
        )
        retryDelegate = consentViewController
        navigateTo(consentViewController)
    }

    private func renderQRCodeUI(with engagementPresentation: EngagementPresentation) {
           // TODO: DCMAW-18470 Refactor QRCodeVC to remove settings / other view states
           // On refresh the top view controller is already a QR screen — replace it in place
           // rather than pushing a new one, to avoid growing the navigation stack each cycle.
           cancelRequiresConfirmation = engagementPresentation.cancelRequiresConfirmation
           if let existing = topViewController as? QRCodeViewController {
               existing.update(engagementPresentation: engagementPresentation)
               return
           }
           let qrCodeViewController = QRCodeViewController(engagementPresentation: engagementPresentation)
           qrCodeViewController.delegate = self

           // Only navigate on success — on failure the delegate has already routed
           // to the error screen and torn down the session.
           guard qrCodeViewController.showQRCode() == .success else { return }
           navigateTo(qrCodeViewController)
       }

    private func navigateTo(_ viewController: UIViewController) {
        setViewControllers([viewController], animated: false)
    }
}

// TODO: DCMAW-23699 Remove Cancel logic from here - driven via new presentation objects
// MARK: - QRCodeViewControllerDelegate
extension HolderNavigationController: @MainActor QRCodeViewControllerDelegate {
    func didTapCancel() {
        Logger.log("Tapped cancel")
        orchestrator.userDidTapCancel()
    }

    func didTapNavigateToSettings() {
        Logger.log("Tapped navigate to settings")
    }
}

// MARK: - UINavigationControllerDelegate
extension HolderNavigationController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        if viewController is TerminalStateViewController || viewController is ErrorViewController {
            isModalInPresentation = false
            return
        }
        // TODO: DCMAW-23709 Remove all logic from here down once all cancel buttons are implemented independently across UI screens
        guard viewController !== viewControllers.first else { return }

        // GDS screens configure their own Cancel bar button
        // so the container must not add a second one.
        if viewController is GDSScreen { return }

        // Legacy UIKit screens still rely on the container provided cancel button below.
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        viewController.navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        viewController.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "CancelButton"
    }

    // TODO: DCMAW-23709 Remove when all UI implemented
    @objc private func cancelButtonTapped() {
        didTapCancel()
    }
    
    func didFailToGenerateQRCode() {
            Logger.log("Failed to generate QR code", level: .error)
            orchestrator.qrCodeGenerationDidFail()
        }
}

// MARK: - Presentation Controller Delegate
extension HolderNavigationController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        handleCancel()
    }
}
