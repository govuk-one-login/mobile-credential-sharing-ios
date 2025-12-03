import HolderUI
import UIKit

class HomePageViewController: UIViewController {
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let navigateButton = UIButton(type: .system)
    var credentialPresenter: CredentialPresenter?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupTitle()
        setupNavigateButton()
        setupActivityIndicator()
    }
    
    private func setupTitle() {
        let titleLabel: UILabel = {
            let label = UILabel()
            label.text = "Welcome to GOV.UK Wallet Sharing"
            label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate(
            [
                titleLabel.centerXAnchor
                    .constraint(equalTo: view.centerXAnchor),
                titleLabel.centerYAnchor
                    .constraint(
                        equalTo: view.safeAreaLayoutGuide.topAnchor,
                    ),
                titleLabel.leadingAnchor
                    .constraint(equalTo: view.leadingAnchor, constant: 12),
                titleLabel.trailingAnchor
                    .constraint(equalTo: view.trailingAnchor, constant: -12)
            ]
        )
    }
    
    private func setupNavigateButton() {
        navigateButton.configuration = .bordered()
        navigateButton.configuration?.baseBackgroundColor = .systemGreen
        navigateButton.configuration?.baseForegroundColor = .white
        navigateButton.configuration?.contentInsets = .init(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
            
        navigateButton.setTitle("Display QR code", for: .normal)
        navigateButton.titleLabel?.font = UIFont
            .preferredFont(forTextStyle: .headline)
        navigateButton.translatesAutoresizingMaskIntoConstraints = false
        navigateButton
            .addTarget(
                self,
                action: #selector(navigateButtonTapped),
                for: .touchUpInside
            )

        view.addSubview(navigateButton)

        NSLayoutConstraint.activate([
            navigateButton.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            navigateButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor
                .constraint(equalTo: navigateButton.topAnchor, constant: -62)
        ])
    }

    @objc private func navigateButtonTapped() {
        activityIndicator.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.navigateToQRCodeView()
        }
    }

    func navigateToQRCodeView() {
        credentialPresenter = CredentialPresenter()
        credentialPresenter?.presentCredential(Data(), over: self)
        activityIndicator.stopAnimating()
    }
}
