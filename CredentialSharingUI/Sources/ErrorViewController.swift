import SharingOrchestration
import UIKit

final class ErrorViewController: UIViewController {
    public static let openSettingsButtonIdentifier = "OpenSettingsButton"
    let error: SessionError
    
    private var displayContent: (title: String, showSettingsCTA: Bool) {
        switch error {
        case .unrecoverablePrerequisite(let prerequisite):
            switch prerequisite {
                
            case .bluetooth(.authorizationDenied):
                return (
                    "Bluetooth access has been denied. Please enable it in Settings to continue.",
                    true
                )
            case .camera(.authorizationDenied):
                return (
                    "Camera access has been denied. Please enable it in Settings to continue.",
                    true
                )
            default:
                return (error.errorDescription, false)
            }
        case .unknown:
            return ("Bluetooth status is currently unknown.", false)
                
        case .generic(let description):
            return (description, false)
        }
    }
    
    init(error: SessionError) {
        self.error = error
        super.init(nibName: nil, bundle: nil)
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
        let content = displayContent
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = content.title
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(titleLabel)
        
        // Open Settings CTA Button (only when applicable)
        if content.showSettingsCTA {
            let openSettingsButton = UIButton(type: .system)
            openSettingsButton.setTitle("Open Settings", for: .normal)
            openSettingsButton.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)
            openSettingsButton.accessibilityIdentifier = ErrorViewController.openSettingsButtonIdentifier
            
            stackView.addArrangedSubview(openSettingsButton)
        }
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    @objc private func openSettingsTapped() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            print("Unable to open settings")
            return
        }

        UIApplication.shared.open(settingsUrl) { success in
            if success {
                print("Successfully opened app settings")
            } else {
                print("Failed to open app settings")
            }
        }
    }
}
