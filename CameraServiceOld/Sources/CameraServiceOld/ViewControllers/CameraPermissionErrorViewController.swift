import UIKit

public class CameraPermissionErrorViewController: UIViewController {

    public static let openSettingsButtonIdentifier = "OpenSettingsButton"

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        // Configure navigation
        navigationItem.title = "Camera Access Required"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissTapped)
        )

        // Create main stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Error message label
        let messageLabel = UILabel()
        messageLabel.text = "Please enable camera permissions to continue"
        messageLabel.font = .systemFont(ofSize: 18, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Open Settings button
        let openSettingsButton = UIButton()
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Open Settings"
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        openSettingsButton.configuration = configuration
        openSettingsButton.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)
        openSettingsButton.accessibilityIdentifier = CameraPermissionErrorViewController.openSettingsButtonIdentifier

        // Add views to stack
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(openSettingsButton)

        view.addSubview(stackView)

        // Setup constraints
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

    @objc private func openSettingsTapped() {
        openAppSettings()
    }

    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            print("Unable to open settings")
            return
        }

        UIApplication.shared.open(settingsUrl) { success in
            if success {
                print("Successfully opened app settings")
            } else {
                print("Failed to open app settings")
            }
        }
    }
}
