import UIKit

public class InvalidQRErrorViewController: UIViewController {

    public static let tryAgainButtonIdentifier = "TryAgainButton"

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        navigationItem.title = "QR Decoding failed"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissTapped)
        )

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = "Cannot use the scanned QR code"
        messageLabel.font = .systemFont(ofSize: 18, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Try again button
        let tryAgainButton = UIButton()
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Try Again"
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        tryAgainButton.configuration = configuration
        tryAgainButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(tryAgainButton)
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            messageLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
        ])
    }

    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
}
