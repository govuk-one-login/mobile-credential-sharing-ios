import UIKit

class VerifierViewController: UIViewController {
    
    static let scanButtonIdentifier = "ScanButton"
    
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
        // Non-functional as per AC2, implementation goes here later
        print("Scan QR code tapped")
    }
}
