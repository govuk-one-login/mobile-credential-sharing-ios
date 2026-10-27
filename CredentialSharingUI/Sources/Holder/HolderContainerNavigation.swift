import DesignSystem
import Logging
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
protocol ConsentRetryDelegate: AnyObject {
    func consentRetryAvailable()
}

@MainActor
class HolderContainerNavigation: UINavigationController {
    var orchestrator: HolderOrchestratorProtocol
    private let analyticsService: AnalyticsService?
    private weak var retryDelegate: ConsentRetryDelegate?

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
        orchestrator.startPresentation()
    }
}

// MARK: - HolderOrchestratorDelegate
extension HolderContainerNavigation: @MainActor HolderOrchestratorDelegate {
    func orchestrator(didUpdateState state: HolderSessionState?) {
        guard let state = state else {
            navigateToErrorView(
                error: .generic("Something went wrong. Try again later.")
            )
            return
        }
        switch state {
        case .notStarted,
             .readyToPresent,
             .processingResponse,
             .terminatingSession:
            break
        case .preflight(let presentation):
            renderGetReadyToShareUI(for: presentation)
        case .presentingEngagement(let qrCode):
            renderQRCodeUI(with: qrCode)
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

    //TODO: Remove Cancel logic from here - driven via new presentation objects
    func orchestratorDidRequestCancelConfirmation() {
        Logger.log("Cancel confirmation dialog presented")
        let alert = UIAlertController(
            title: nil,
            message: "Are you sure you want to cancel?",
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            Logger.log("Cancel confirmation confirmed — cancelling session")
            self?.orchestrator.userDidConfirmCancel()
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
        navigateTo(ErrorViewController(error: error))
    }

    private func renderGetReadyToShareUI(for presentation: ReadinessPresentation) {
        navigateTo(
            ReadinessViewController(
                presentation: presentation,
                orchestrator: orchestrator
            )
        )
    }

    private func renderConsentUI(for presentation: ConsentPresentation) {
        let consentViewController = ConsentViewController(
            presentation: presentation,
            orchestrator: orchestrator
        )
        retryDelegate = consentViewController
        navigateTo(consentViewController)
    }

    private func renderQRCodeUI(with qrCode: UIImage?) {
        // TODO: DCMAW-18470 Refactor QRCodeVC to remove settings / other view states
        let qrCodeViewController = QRCodeViewController(qrCode: qrCode)
        qrCodeViewController.delegate = self
        qrCodeViewController.showQRCode()
        navigateTo(qrCodeViewController)
    }

    private func navigateTo(_ view: UIViewController) {
        pushViewController(view, animated: false)
    }
}

//TODO: Remove Cancel logic from here - driven via new presentation objects
// MARK: - QRCodeViewControllerDelegate
extension HolderContainerNavigation: @MainActor QRCodeViewControllerDelegate {
    func didTapCancel() {
        Logger.log("Tapped cancel")
        orchestrator.userDidTapCancel()
    }

    func didTapNavigateToSettings() {
        Logger.log("Tapped navigate to settings")
    }
}

// MARK: - UINavigationControllerDelegate
extension HolderContainerNavigation: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard viewController !== viewControllers.first else { return }

        if viewController is TerminalStateViewController || viewController is ErrorViewController {
            isModalInPresentation = false
            return
        }

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

    @objc private func cancelButtonTapped() {
        didTapCancel()
    }
}

// MARK: - Presentation Controller Delegate
extension HolderContainerNavigation: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        didTapCancel()
    }
}
