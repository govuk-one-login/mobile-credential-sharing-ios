import CredentialSharingUI
import Logging
import UIKit

class HolderViewController: UIViewController {
    static let presentButtonIdentifier = "PresentCredentialButton"
    static let activityIndicatorIdentifier = "CredentialActivityIndicator"

    let activityIndicator = UIActivityIndicatorView(style: .large)
    private let loggingService: AnalyticsService = DebugLoggingService()
    
    private lazy var credentialPresenter: CredentialPresenter = {
        CredentialPresenter(
            credentialProvider: MockCredentialProvider(activeCredential: .janeDoe()),
            logger: loggingService,
            completion: { [weak self] in
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
