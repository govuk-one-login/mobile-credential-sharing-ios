import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

class PreflightPermissionViewController: UIViewController {
    static let enablePermissionsButtonIdentifier = "EnablePermissionsButton"
    
    private let missingPrerequisites: [MissingPrerequisite]
    private let onResolve: (MissingPrerequisite) -> Void
    
    init(_ missingPrerequisites: [MissingPrerequisite], onResolve: @escaping (MissingPrerequisite) -> Void) {
        self.missingPrerequisites = missingPrerequisites
        self.onResolve = onResolve
        super.init(nibName: nil, bundle: nil)
        guard missingPrerequisites.count > 0 else {
            assertionFailure("Missing permissions should not be empty")
            return
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        
        setupView()
    }
    
    private func setupView() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 52),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -52)
        ])
        
        for missingPrerequisite in missingPrerequisites {
            let label = UILabel()
            label.text = "This app needs to access your \(missingPrerequisite.description)."
            label.numberOfLines = 0
            label.textAlignment = .center
            label.lineBreakMode = .byWordWrapping
            stackView.addArrangedSubview(label)
            
            let button = UIButton(type: .system)
            button.setTitle("Enable \(missingPrerequisite.description) prerequisite", for: .normal)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.accessibilityIdentifier = PreflightPermissionViewController.enablePermissionsButtonIdentifier
            
            button.addAction(UIAction { [weak self] _ in
            self?.onResolve(missingPrerequisite)
            }, for: .touchUpInside)
            
            stackView.addArrangedSubview(button)
        }
    }
}
