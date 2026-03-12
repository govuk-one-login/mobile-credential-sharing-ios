import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
class HolderContainer: UIViewController {
    static let activityIndicatorIdentifier = "HolderContainerActivityIndicator"
    var orchestrator: HolderOrchestratorProtocol
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    init(orchestrator: HolderOrchestratorProtocol = HolderOrchestrator()) {
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
    func render(for state: HolderSessionState?) {
        guard let state = state else {
            navigateToErrorView(titleText: "Something went wrong. Try again later.")
            return
        }
        switch state {
        case .notStarted:
            break
        case .preflight(missingPermissions: let missingPermissions):
            renderPreflightUI(for: missingPermissions)
        case .readyToPresent:
            break
        case .presentingEngagement(let qrCode):
            renderQRCodeUI(with: qrCode)
        case .processingEstablishment:
            navigateTo(ProcessingEstablishmentViewController())
        case .requestReceived:
            break
        case .processingResponse:
            break
        case .complete:
            break
        case .cancelled:
            navigationController?.dismiss(animated: true)
        case .error(let errorDescription):
            navigateToErrorView(titleText: errorDescription)
        }
    }
    
    private func navigateToErrorView(titleText: String) {
        let errorViewController = ErrorViewController(titleText: titleText)
        navigationController?.pushViewController(errorViewController, animated: true)
    }
    
    private func renderPreflightUI(for missingPermissions: [Capability]) {
        navigateTo(
            PreflightPermissionViewController(missingPermissions, orchestrator)
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
        navigationController?.pushViewController(view, animated: true)
        activityIndicator.stopAnimating()
    }
}

extension HolderContainer: @MainActor QRCodeViewControllerDelegate {
    func didTapCancel() {
        print("Tapped cancel")
        self.orchestrator.cancelPresentation()
    }
    
    func didTapNavigateToSettings() {
        print("Tapped navigate to settings")
    }
}
