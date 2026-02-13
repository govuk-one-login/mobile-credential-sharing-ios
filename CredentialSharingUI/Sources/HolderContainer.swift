import Orchestration
import PrerequisiteGate
import UIKit

public class HolderContainer: UIViewController {
    static let activityIndicatorIdentifier = "CredentialActivityIndicator"
    var orchestrator: HolderOrchestratorProtocol
    let activityIndicator = UIActivityIndicatorView(style: .large)
    var navController: UINavigationController?

    
    public init(over baseViewController: UIViewController, orchestrator: HolderOrchestratorProtocol = HolderOrchestrator()) {
        self.orchestrator = orchestrator
        self.navController = baseViewController.navigationController
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
        self.orchestrator.startPresentation()
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
    
    public func startPresentation() {
        orchestrator.startPresentation()
    }
}

extension HolderContainer: @MainActor HolderOrchestratorDelegate {
    public func render(for state: Orchestration.HolderSessionState?) {
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
            // TODO: DCMAW-18470 Add bluetooth flow here
            break
        case .presentingEngagement:
            break
        case .connecting:
            break
        case .requestReceived:
            break
        case .processingResponse:
            break
        case .complete:
            break
        case .error(let errorDescription):
            navigateToErrorView(titleText: errorDescription)
        }
    }
    
    private func navigateToErrorView(titleText: String) {
        let errorViewController = ErrorViewController(titleText: titleText)
        navController?.present(errorViewController, animated: true)
    }
    
    private func renderPreflightUI(for missingPermissions: [Capability]) {
        for capability in missingPermissions {
            switch capability {
            case .bluetooth(let authorization):
                if authorization == .denied {
                    navigateToErrorView(titleText: "Permission permanently denied")
                } else {
                    navigateToNextView(
                        PreflightPermissionViewController(capability, orchestrator)
                    )
                }
            case .camera:
                break
            }
        }
    }
    
    private func navigateToNextView(_ view: UIViewController) {
        navController?.present(view, animated: true)
    }
}
