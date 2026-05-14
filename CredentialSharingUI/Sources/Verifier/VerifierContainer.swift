import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
class VerifierContainer: UIViewController {
    var orchestrator: VerifierOrchestratorProtocol

    init(orchestrator: VerifierOrchestratorProtocol = VerifierOrchestrator()) {
        self.orchestrator = orchestrator
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        orchestrator.startVerification()
    }
}

extension VerifierContainer: @MainActor VerifierOrchestratorDelegate {
    func orchestrator(didUpdateState state: VerifierSessionState?) {
        guard let state = state else {
            print("Something went wrong. Try again later.")
            return
        }
        
        switch state {
        case .notStarted:
            break
        case .preflight(missingPrerequisites: let missingPrerequisites):
            renderPreflightUI(for: missingPrerequisites)
        case .readyToScan:
            break
        case .cancelled:
            navigationController?.dismiss(animated: true)
        case .failed(let error):
            print("Failed with error: \(error)")
        }
    }
    
    private func renderPreflightUI(for missingPrerequisites: [MissingPrerequisite]) {
        navigateTo(
            PreflightPermissionViewController(missingPrerequisites, orchestrator)
        )
    }
    
    private func navigateTo(_ view: UIViewController) {
        navigationController?.pushViewController(view, animated: false)
    }
}
