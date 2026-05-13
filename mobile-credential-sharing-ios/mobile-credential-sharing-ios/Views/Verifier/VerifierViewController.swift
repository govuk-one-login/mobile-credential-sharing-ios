import CredentialSharingUI
import SharingCameraService
import UIKit

class VerifierViewController: UIViewController {
    static let startVerificationIdentifier = "StartVerificationButton"
    private let cameraManager: CameraManagerProtocol

    init(cameraManager: CameraManagerProtocol = CameraManager()) {
        self.cameraManager = cameraManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.cameraManager = CameraManager()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        restorationIdentifier = "VerifierViewController"
        title = "Verifier"
        navigationItem.largeTitleDisplayMode = .always
        setupView()
    }
    
    private func setupView() {
        let startVerificationButton = UIButton(type: .system)
        startVerificationButton.setTitle("Start verification journey", for: .normal)
        startVerificationButton.addTarget(self, action: #selector(startVerificationTapped), for: .touchUpInside)
        startVerificationButton.translatesAutoresizingMaskIntoConstraints = false
        startVerificationButton.accessibilityIdentifier = VerifierViewController.startVerificationIdentifier
        view.addSubview(startVerificationButton)
        
        NSLayoutConstraint.activate([
            startVerificationButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startVerificationButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func startVerificationTapped() {
        let journeyVC = VerifierContainerNavigation()
        present(journeyVC, animated: true)
    }
}
