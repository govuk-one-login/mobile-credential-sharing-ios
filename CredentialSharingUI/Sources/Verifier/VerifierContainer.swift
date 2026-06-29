import AVFoundation
import GDSCommon
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
class VerifierContainer: UIViewController {
    var orchestrator: VerifierOrchestratorProtocol
    let attributeGroup: AttributeGroup

    init(
        orchestrator: VerifierOrchestratorProtocol = VerifierOrchestrator(),
        attributeGroup: AttributeGroup
    ) {
        self.orchestrator = orchestrator
        self.attributeGroup = attributeGroup
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        orchestrator.startVerification(attributeGroup: attributeGroup)
    }
}

extension VerifierContainer: @MainActor VerifierOrchestratorDelegate {
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

    private func renderScannerUI() {
        let scannerVC = ScanningViewController<AVCaptureSession>(viewModel: QRScannerViewModel(orchestrator: orchestrator))
        navigationController?.pushViewController(scannerVC, animated: false)
    }

    private func navigateTo(_ view: UIViewController) {
        navigationController?.pushViewController(view, animated: false)
    }
}
