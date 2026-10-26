import Logging
import SharingLogging
import SharingOrchestration
import UIKit

class ErrorViewController: UIViewController {
    public static let openSettingsButtonIdentifier = "OpenSettingsButton"
    // Replace with the screen_id assigned to this screen in Confluence.
    private static let screenID = "00000000-0000-0000-0000-000000000000"

    let error: SessionError
    private let analyticsService: AnalyticsService?
    
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
                return (error.errorDescription ?? "Unkown error", false)
            }
        case .incorrectSessionState(let state):
            return ("Current state is invalid: \(state).", false)
        case .sequencingViolation:
            return (error.errorDescription ?? "Sequencing violation", false)
        case .protocolError:
            return (error.errorDescription ?? "Protocol Error", false)
        case .policyViolation:
            return (error.errorDescription ?? "Policy violation", false)
        case .invalidDeviceRequest:
            return (error.errorDescription ?? "Invalid Device Request", false)
        case .peerTermination:
            return (error.errorDescription ?? "Peer Termination", false)
        case .transportError:
            return (error.errorDescription ?? "BLE Disconnected", false)
        case .unknown:
            return ("State is currently unknown.", false)
        case .generic(let description):
            return (description, false)
        }
    }
    
    init(error: SessionError, analyticsService: AnalyticsService? = nil) {
        self.error = error
        self.analyticsService = analyticsService
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
        trackScreenView()
    }

    private func trackScreenView() {
        analyticsService?.trackScreenEvent(
            ScreenViewEventName.screenViewError,
            title: displayContent.title,
            screenClass: .errorScreen,
            screenID: Self.screenID,
            error: error
        )
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
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            Logger.log("Unable to open settings", level: .error)
            return
        }

        UIApplication.shared.open(settingsUrl)
    }
}
