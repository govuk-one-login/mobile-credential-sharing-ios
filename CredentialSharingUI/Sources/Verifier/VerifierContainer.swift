import AVFoundation
import GDSCommon
import SharingCryptoService
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
class VerifierContainer: UIViewController {
    static let cancelConfirmationYesIdentifier = "cancelConfirmationYes"
    static let cancelConfirmationNoIdentifier = "cancelConfirmationNo"

    var orchestrator: VerifierOrchestratorProtocol
    let config: VerifierConfig

    init(
        orchestrator: VerifierOrchestratorProtocol = VerifierOrchestrator(),
        config: VerifierConfig
    ) {
        self.orchestrator = orchestrator
        self.config = config
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        orchestrator.startVerification(config: config)
    }

    func didTapCancel() {
        orchestrator.cancelVerification()
    }

    /// Called when the user confirms cancellation via the alert dialog.
    func didConfirmCancel() {
        OSLoggingService.shared.logEvent(LoggingEvents.verifierCancelAlertSessionDown)
        orchestrator.userDidConfirmCancel()
    }

    /// Called when the user dismisses the cancellation alert dialog.
    func didDismissCancel() {
        OSLoggingService.shared.logEvent(LoggingEvents.cancelledConfirmationSessionAlive)
    }
}

extension VerifierContainer: @MainActor VerifierOrchestratorDelegate {
    func orchestratorDidRequestCancelConfirmation() {
        let alert = UIAlertController(
            title: nil,
            message: "Are you sure you want to cancel?",
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            self?.didConfirmCancel()
        }
        confirmAction.accessibilityIdentifier = VerifierContainer.cancelConfirmationYesIdentifier

        let dismissAction = UIAlertAction(title: "No", style: .cancel) { [weak self] _ in
            self?.didDismissCancel()
        }
        dismissAction.accessibilityIdentifier = VerifierContainer.cancelConfirmationNoIdentifier

        alert.addAction(confirmAction)
        alert.addAction(dismissAction)

        navigationController?.present(alert, animated: true)
    }

    func orchestrator(didUpdateState state: VerifierSessionState?) {
        guard let state = state else {
            navigateToErrorView(error: .incorrectSessionState("State passed is nil"))
            return
        }
        
        switch state {
        case .notStarted:
            break
        case .preflight(missingPrerequisites: let missingPrerequisites):
            renderPreflightUI(for: missingPrerequisites)
        case .readyToScan:
            renderScannerUI()
        case .processingEngagement:
            navigateTo(LoadingViewController(loadingTitle: "Processing..."))
        case .connecting:
            navigateTo(LoadingViewController(loadingTitle: "Connecting..."))
        case .verifying:
            navigateTo(LoadingViewController(loadingTitle: "Verifying..."))
        case .terminatingSession:
            break
        case .success(let deviceResponse):
            navigateTo(AttributeResultViewController(deviceResponse: deviceResponse))
        case .cancelled:
            navigationController?.dismiss(animated: true)
        case .failed(let error):
            OSLoggingService.shared.logEvent(LoggingEvents.failedWithError, parameters: ["error": error])
            navigateToErrorView(error: error)
        }
    }
        
    private func navigateToErrorView(error: SessionError) {
        let errorViewController = ErrorViewController(error: error)
        navigateTo(errorViewController)
    }
    
    private func renderPreflightUI(for missingPrerequisites: [MissingPrerequisite]) {
        navigateTo(
            PreflightPermissionViewController(missingPrerequisites, onResolve: orchestrator.resolve)
        )
    }

    private func renderScannerUI() {
        let scannerVC = ScanningViewController<AVCaptureSession>(viewModel: QRScannerViewModel(orchestrator: orchestrator))
        navigationController?.pushViewController(scannerVC, animated: false)
    }

    private func navigateTo(_ view: UIViewController) {
        navigationController?.pushViewController(view, animated: false)
    }
}
