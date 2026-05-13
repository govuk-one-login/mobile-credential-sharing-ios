import SharingOrchestration
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
        // UI Navigation to be done here
    }
}
