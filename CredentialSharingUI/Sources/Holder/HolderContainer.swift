import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
class HolderContainer: UIViewController {
    static let activityIndicatorIdentifier = "HolderContainerActivityIndicator"
    var orchestrator: any HolderOrchestratorProtocol
    let activityIndicator = UIActivityIndicatorView(style: .large)

    init(orchestrator: any HolderOrchestratorProtocol) {
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
        orchestrator.start()
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
        case .isoReadyToPresent:
            break
        case .isoPresentingEngagement(let qrCode):
            renderQRCodeUI(with: qrCode)
        case .isoProcessingEstablishment:
            navigateTo(LoadingViewController())
        case .awaitingUserConsent(let deviceRequest):
            navigateTo(ConsentViewController(deviceRequest: deviceRequest, orchestrator: orchestrator))
        case .processingResponse:
            break
        case .success:
            print("Response sent successfully")
        case .cancelled:
            navigationController?.dismiss(animated: true)
        case .failed(let error):
            print("Failed with error: \(error)")
            navigateToErrorView(error: error)
        }
    }
    
    private func navigateToErrorView(error: SessionError) {
        let errorViewController = ErrorViewController(error: error)
        navigationController?.pushViewController(errorViewController, animated: false)
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
        print("Tapped cancel")
        self.orchestrator.cancel()
    }
    
    func didTapNavigateToSettings() {
        print("Tapped navigate to settings")
    }
}
