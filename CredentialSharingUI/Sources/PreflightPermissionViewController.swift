import Orchestration
import PrerequisiteGate
import UIKit

class PreflightPermissionViewController: UIViewController {
    static let enablePermissionsButtonIdentifier = "EnablePermissionsButton"
    
    private let missingPermissions: [Capability]
    private let orchestrator: HolderOrchestratorProtocol
    
    init(_ missingPermissions: [Capability], _ orchestrator: HolderOrchestratorProtocol) {
        self.missingPermissions = missingPermissions
        self.orchestrator = orchestrator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        
        let label = UILabel()
        label.text = "This app needs to access your \(missingPermissions.first?.rawValue)."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        let button = UIButton(type: .system)
        button.setTitle("Enable \(missingPermissions.first?.rawValue) permissions", for: .normal)
        button.addTarget(self, action: #selector(didTapAllow), for: .touchUpInside)
        button.accessibilityIdentifier = PreflightPermissionViewController.enablePermissionsButtonIdentifier
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc func didTapAllow() {
        orchestrator.requestPermission(for: missingPermissions.first!)
    }
}
