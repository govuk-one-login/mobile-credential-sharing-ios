import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
class HolderContainer: UIViewController {
    static let activityIndicatorIdentifier = "HolderContainerActivityIndicator"
    var orchestrator: HolderOrchestratorProtocol
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    init(orchestrator: HolderOrchestratorProtocol) {
        self.orchestrator = orchestrator
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityIdentifier = HolderContainer.activityIndicatorIdentifier
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor
                .constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        activityIndicator.startAnimating()
        orchestrator.startPresentation()
    }
}

extension HolderContainer: @MainActor HolderOrchestratorDelegate {
    func orchestrator(didUpdateState state: HolderSessionState?) {
        guard let state = state else {
            navigateToErrorView(
                error: .generic("Something went wrong. Try again later.")
            )
            return
        }
        switch state {
        case .notStarted:
            break
        case .preflight(missingPrerequisites: let missingPrerequisites):
            renderPreflightUI(for: missingPrerequisites)
        case .readyToPresent:
            break
        case .presentingEngagement(let qrCode):
            renderQRCodeUI(with: qrCode)
        case .processingEstablishment:
            navigateTo(LoadingViewController())
        case .awaitingUserConsent(let deviceRequest):
            navigateTo(ConsentViewController(deviceRequest: deviceRequest, orchestrator: orchestrator))
        case .processingResponse:
            break
        case .awaitingVerifierResolution:
            Logger.log("Navigating to details shared screen")
            navigateTo(TerminalStateViewController(message: "Details shared"))
        case .success(let reason):
            switch reason {
            case .responseSent:
                break
            case .denialResponse:
                navigationController?.dismiss(animated: true)
            case .emptyResponse:
                Logger.log("Navigating to unfulfillable request screen")
                navigateTo(TerminalStateViewController(message: "Unfulfillable request"))
            }
        case .cancelled:
            navigationController?.dismiss(animated: true)
        case .failed(let error):
            switch error {
            case .transportError:
                navigateToErrorView(error: error)
            case .peerTermination
                where navigationController?.topViewController is TerminalStateViewController:
                // Peer terminated while 'details shared' screen is visible — remain on current screen
                break
            default:
                Logger.log("Failed with error: \(error)", level: .error)
                navigateToErrorView(error: error)
            }
        case .terminatingSession:
            break
        }
    }

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

        navigationController?.present(alert, animated: true)
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
    
    private func renderQRCodeUI(with qrCode: UIImage?) {
        // TODO: DCMAW-18470 Refactor QRCodeVC to remove settings / other view states
        let qrCodeViewController = QRCodeViewController(qrCode: qrCode)
        qrCodeViewController.delegate = self
        qrCodeViewController.showQRCode()
        navigateTo(qrCodeViewController)
    }
    
    private func navigateTo(_ view: UIViewController) {
        navigationController?.pushViewController(view, animated: false)
        activityIndicator.stopAnimating()
    }
}

extension HolderContainer: @MainActor QRCodeViewControllerDelegate {
    func didTapCancel() {
        Logger.log("Tapped cancel")
        self.orchestrator.userDidTapCancel()
    }
    
    func didTapNavigateToSettings() {
        Logger.log("Tapped navigate to settings")
    }
}
