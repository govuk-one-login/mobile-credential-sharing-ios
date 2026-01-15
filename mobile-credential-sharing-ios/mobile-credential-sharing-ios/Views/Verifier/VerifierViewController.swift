import CameraService
import UIKit

class VerifierViewController: UIViewController {
    
    static let scanButtonIdentifier = "ScanButton"
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
        let scanButton = UIButton(type: .system)
        scanButton.setTitle("Scan Credential", for: .normal)
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.accessibilityIdentifier = VerifierViewController.scanButtonIdentifier
        view.addSubview(scanButton)
        
        NSLayoutConstraint.activate([
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func scanButtonTapped() {
        Task {
            do {
                try await cameraManager.presentQRScanner(from: self)
            } catch {
                print("Camera error: \(error.localizedDescription)")
            }
        }
    }
}
