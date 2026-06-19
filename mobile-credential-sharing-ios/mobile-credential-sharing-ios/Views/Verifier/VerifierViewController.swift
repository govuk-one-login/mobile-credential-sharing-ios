import CredentialSharingUI
import SharingOrchestration
import UIKit

class VerifierViewController: UIViewController {
    static let startVerificationIdentifier = "StartVerificationButton"

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
        guard let attributeGroup = AttributeGroup(
            mdlAttributes: [
                .init(attribute: .givenName, intentToRetain: true),
                .init(attribute: .ageOver(18), intentToRetain: false)
            ],
            gbMdlAttributes: [
                .init(attribute: .title, intentToRetain: false)
            ]
        ) else {
            return
        }
        
        let journeyVC = VerifierContainerNavigation(attributeGroup: attributeGroup)
        present(journeyVC, animated: true)
    }
}
