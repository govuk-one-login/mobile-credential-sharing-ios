import Orchestration
import PrerequisiteGate
import UIKit

public class HolderContainerNavigation: UINavigationController {
    init(holderContainer: HolderContainer) {
        super.init(rootViewController: holderContainer)
    }
    
    public convenience init() {
        self.init(holderContainer: HolderContainer())
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class HolderContainer: UIViewController {
    static let activityIndicatorIdentifier = "HolderContainerActivityIndicator"
    var orchestrator: HolderOrchestratorProtocol
    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    public init(orchestrator: HolderOrchestratorProtocol = HolderOrchestrator()) {
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
        navigationController?.pushViewController(errorViewController, animated: true)
    }
    
    private func renderPreflightUI(for missingPermissions: [Capability]) {
        navigateTo(
            PreflightPermissionViewController(missingPermissions, orchestrator)
        )
    }
    
    private func navigateTo(_ view: UIViewController) {
        navigationController?.pushViewController(view, animated: true)
        activityIndicator.stopAnimating()
    }
}
