import Bluetooth
import UIKit
import Bluetooth

class HomePageViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupTitle()
        setupNavigateButton()
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
        let navigateButton = UIButton(type: .system)
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

    @objc private func navigateButtonTapped() {
        navigateToNewView()
    }

    private func navigateToNewView() {
        let newVC = QRCodeViewController()

        guard let navigationController = self.navigationController else {
            fatalError(
                "Error: HomeViewController is not embedded in a UINavigationController."
            )
        }
        navigationController.pushViewController(newVC, animated: true)
    }
}
