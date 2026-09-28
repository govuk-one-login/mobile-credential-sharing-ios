import CredentialSharingUI
import SharingCryptoService
import SharingOrchestration
import SwiftASN1
import UIKit
import X509

class VerifierViewController: UIViewController {
    static let attributeGroupMenuIdentifier = "AttributeGroupMenuButton"
    static let readerAuthMenuIdentifier = "ReaderAuthMenuButton"
    static let verifyCredentialIdentifier = "VerifyCredentialButton"

    /// The currently selected attribute-group option (mandatory single-select).
    private(set) var selectedAttributeOption: VerifierAttributeOption = .default {
        didSet { attributeGroupButton.setTitle(selectedAttributeOption.displayName, for: .normal) }
    }

    /// The currently selected ReaderAuth certificate profile (mandatory single-select).
    private(set) var selectedReaderAuthOption: ReaderAuthProfileOption = .default {
        didSet { readerAuthButton.setTitle(selectedReaderAuthOption.displayName, for: .normal) }
    }

    private let attributeGroupButton = UIButton(type: .system)
    private let readerAuthButton = UIButton(type: .system)
    private let verifyButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        restorationIdentifier = "VerifierViewController"
        title = "Verifier"
        navigationItem.largeTitleDisplayMode = .always
        setupView()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        configureMenuButton(
            attributeGroupButton,
            identifier: Self.attributeGroupMenuIdentifier,
            title: selectedAttributeOption.displayName,
            actions: VerifierAttributeOption.allCases.map { option in
                UIAction(
                    title: option.displayName,
                    state: option == selectedAttributeOption ? .on : .off
                ) { [weak self] _ in self?.selectedAttributeOption = option }
            }
        )

        configureMenuButton(
            readerAuthButton,
            identifier: Self.readerAuthMenuIdentifier,
            title: selectedReaderAuthOption.displayName,
            actions: ReaderAuthProfileOption.allCases.map { option in
                UIAction(
                    title: option.displayName,
                    state: option == selectedReaderAuthOption ? .on : .off
                ) { [weak self] _ in self?.selectedReaderAuthOption = option }
            }
        )

        verifyButton.setTitle("Verify Credential", for: .normal)
        verifyButton.accessibilityIdentifier = Self.verifyCredentialIdentifier
        verifyButton.addTarget(self, action: #selector(verifyCredentialTapped), for: .touchUpInside)
        verifyButton.translatesAutoresizingMaskIntoConstraints = false

        let optionsStack = UIStackView(arrangedSubviews: [
            makeLabel("Attribute group"),
            attributeGroupButton,
            makeLabel("Reader Auth certificate"),
            readerAuthButton
        ])
        optionsStack.axis = .vertical
        optionsStack.spacing = 8
        optionsStack.alignment = .fill
        optionsStack.setCustomSpacing(24, after: attributeGroupButton)
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(optionsStack)
        view.addSubview(verifyButton)

        NSLayoutConstraint.activate([
            optionsStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            optionsStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            optionsStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            verifyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            verifyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    /// Configures a button as a single-select drop-down: exactly one action is always selected,
    /// none can be deselected.
    private func configureMenuButton(
        _ button: UIButton,
        identifier: String,
        title: String,
        actions: [UIAction]
    ) {
        button.accessibilityIdentifier = identifier
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        var config = UIButton.Configuration.bordered()
        config.indicator = .popup
        button.configuration = config
        button.setTitle(title, for: .normal)
        button.menu = UIMenu(options: .singleSelection, children: actions)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
    }

    private func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        return label
    }

    @objc private func verifyCredentialTapped() {
        guard let attributeGroup = buildAttributeGroup(),
              let certificate = loadTestIssuerCertificate() else { return }

        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: certificate,
            readerAuthProfile: try? selectedReaderAuthOption.load()
        )
        present(VerifierContainerNavigation(config: config), animated: true)
    }

    /// Loads a self-signed test certificate for development purposes.
    /// In production, the host app provides the real issuer root CA.
    private func loadTestIssuerCertificate() -> Certificate? {
        // A valid self-signed EC P-256 certificate (CN=Test Issuer) for test/demo use.
        // Replace with a real issuer root CA in production integration.
        // swiftlint:disable:next line_length
        let base64DER = "MIIBgDCCASegAwIBAgIUVOEboNCA04tyVsELHWT+C9XNYpMwCgYIKoZIzj0EAwIwFjEUMBIGA1UEAwwLVGVzdCBJc3N1ZXIwHhcNMjYwODE4MTAxNDIwWhcNMzYwODE1MTAxNDIwWjAWMRQwEgYDVQQDDAtUZXN0IElzc3VlcjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABGMSAO8t+HOpxUBMgVKtL8rW2TXLAUwLICd8C1sB1jr1npySabw0Ry1Fhjz4zkQXmXvJMxrhEg5FOeG1DNzI33ajUzBRMB0GA1UdDgQWBBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAfBgNVHSMEGDAWgBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIDgfVsLSvrcafPDOwNpmMAYSdlxbADGcbDrKAiZ0SSeYAiAwai384arQMjr5Ezw0FBguft578i+vWikUoKtvD1Fe7A=="
        guard let certData = Data(base64Encoded: base64DER) else { return nil }
        return try? Certificate(derEncoded: Array(certData))
    }

    /// Builds the `AttributeGroup` for the currently selected attribute option.
    func buildAttributeGroup() -> AttributeGroup? {
        selectedAttributeOption.attributeGroup
    }
}
