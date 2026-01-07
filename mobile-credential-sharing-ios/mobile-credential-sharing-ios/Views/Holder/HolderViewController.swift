import UIKit
import HolderUI

class HolderViewController: UIViewController {
    let activityIndicator = UIActivityIndicatorView(style: .large)
    var credentialPresenter: CredentialPresenting?
    
    static let presentButtonIdentifier = "PresentCredentialButton"
    static let activityIndicatorIdentifier = "CredentialActivityIndicator"

    override func viewDidLoad() {
        super.viewDidLoad()
        restorationIdentifier = "HolderViewController"
        title = "Holder"
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
        if credentialPresenter == nil {
            credentialPresenter = CredentialPresenter()
        }
        
        credentialPresenter?.presentCredential(Data(), over: self)
        activityIndicator.stopAnimating()
    }
}
