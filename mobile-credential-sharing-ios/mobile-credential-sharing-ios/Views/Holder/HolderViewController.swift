import CredentialSharingUI
import UIKit

class HolderViewController: UIViewController {
    static let presentButtonIdentifier = "PresentCredentialButton"
    static let activityIndicatorIdentifier = "CredentialActivityIndicator"

    let activityIndicator = UIActivityIndicatorView(style: .large)
    
    private lazy var credentialPresenter: CredentialPresenter = {
        CredentialPresenter(
            credentialProvider: MockCredentialProvider(),
            logger: { message in
                print("[CredentialPresenter] \(message)")
            },
            completion: { [weak self] in
                print("[CredentialPresenter] Sharing session completed")
                self?.dismiss(animated: true)
            }
        )
    }()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        restorationIdentifier = "HolderViewController"
        title = "Holder"
        navigationItem.largeTitleDisplayMode = .always
        setupView()
    }
    
    private func setupView() {
        let presentButton = UIButton(type: .system)
        presentButton.setTitle("Present Credential", for: .normal)
        presentButton.addTarget(self, action: #selector(presentButtonTapped), for: .touchUpInside)
        presentButton.translatesAutoresizingMaskIntoConstraints = false
        presentButton.accessibilityIdentifier = HolderViewController.presentButtonIdentifier
        view.addSubview(presentButton)
        
        NSLayoutConstraint.activate([
            presentButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            presentButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityIdentifier = HolderViewController.activityIndicatorIdentifier
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor
                .constraint(equalTo: presentButton.topAnchor, constant: -62)
        ])
    }

    @objc private func presentButtonTapped() {
        activityIndicator.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.navigateToQRCodeView()
        }
    }

    func navigateToQRCodeView() {
        let journeyVC = credentialPresenter.viewControllerForSharingJourney()
        present(journeyVC, animated: true)
        activityIndicator.stopAnimating()
    }
}

// MARK: - Mock Credential Provider
class MockCredentialProvider: CredentialProvider {
    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        // Mock implementation - returns dummy credential data
        print("[MockCredentialProvider] Requested document types: \(request.documentTypes)")
        
        // In a real app, this would retrieve and decrypt the credential from secure storage
        let mockCBORData = Data() // Placeholder for actual CBOR credential data
        
        return [Credential(
            id: "mock-credential-id",
            rawCredential: mockCBORData
        )]
    }
    
    func sign(payload: Data, documentId: String) async throws -> Data {
        // Mock implementation - returns dummy signature
        print("[MockCredentialProvider] Signing payload for document: \(documentId)")
        
        // In a real app, this would sign using Secure Enclave
        let mockSignature = Data() // Placeholder for actual signature
        
        return mockSignature
    }
}
