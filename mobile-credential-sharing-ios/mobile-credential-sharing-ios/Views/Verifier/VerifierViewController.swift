import CredentialSharingUI
import Logging
import SharingCryptoService
import SharingLogging
import SharingOrchestration
import SwiftASN1
import UIKit
import X509

class VerifierViewController: UIViewController {
    static let attributeGroupMenuIdentifier = "AttributeGroupMenuButton"
    static let readerAuthMenuIdentifier = "ReaderAuthMenuButton"
    static let verifyCredentialIdentifier = "VerifyCredentialButton"
    static let notProvisionedAlertIdentifier = "ReaderAuthNotProvisionedAlert"

    static let notProvisionedAlertTitle = "Certificate not provisioned"
    static let notProvisionedAlertMessage = """
    This build was not provisioned by the deployment pipeline, so this reader certificate is a \
    placeholder. Publish through the pipeline to obtain a valid certificate before verifying.
    """

    /// The outcome of a verify request: either blocked because the selected reader-auth profile is
    /// an unprovisioned placeholder, or ready to proceed with a built configuration.
    enum VerificationOutcome: Equatable {
        case blocked
        case proceed(VerifierConfig)

        static func == (lhs: VerificationOutcome, rhs: VerificationOutcome) -> Bool {
            switch (lhs, rhs) {
            case (.blocked, .blocked):
                return true
            case (.proceed, .proceed):
                return true
            default:
                return false
            }
        }
    }

    /// The currently selected attribute-group option.
    private(set) var selectedAttributeOption: VerifierAttributeOption = .default {
        didSet { attributeGroupButton.setTitle(selectedAttributeOption.displayName, for: .normal) }
    }

    /// The currently selected ReaderAuth certificate profile.
    private(set) var selectedReaderAuthOption: ReaderAuthProfileOption = .default {
        didSet { readerAuthButton.setTitle(selectedReaderAuthOption.displayName, for: .normal) }
    }

    /// Classifies the selected reader-auth leaf as provisioned or an unprovisioned placeholder.
    private let certificateValidator: ReaderAuthCertificateValidator

    /// The bundle used to load reader-auth profile assets. Defaults to `.main`; tests inject a
    /// test bundle so the real valid profile resolves under the test host.
    private let resourceBundle: Bundle

    private let attributeGroupButton = UIButton(type: .system)
    private let readerAuthButton = UIButton(type: .system)
    private let verifyButton = UIButton(type: .system)

    init(
        certificateValidator: ReaderAuthCertificateValidator = ReaderAuthCertificateValidator(),
        resourceBundle: Bundle = .main
    ) {
        self.certificateValidator = certificateValidator
        self.resourceBundle = resourceBundle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.certificateValidator = ReaderAuthCertificateValidator()
        self.resourceBundle = .main
        super.init(coder: coder)
    }

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
        switch verificationOutcome() {
        case .blocked:
            presentNotProvisionedAlert()
        case .proceed(let config):
            present(VerifierContainerNavigation(config: config), animated: true)
        }
    }

    /// Computes the outcome of a verify request without performing any UIKit presentation, so the
    /// decision can be unit-tested directly.
    ///
    /// Returns `.blocked` when the selected reader-auth profile is an unprovisioned placeholder (the
    /// build did not go through the deployment pipeline), or when required inputs cannot be built.
    /// Otherwise returns `.proceed` with the configured ``VerifierConfig``.
    func verificationOutcome() -> VerificationOutcome {
        guard certificateValidator.validate(selectedReaderAuthOption) == .valid else {
            return .blocked
        }

        guard let attributeGroup = buildAttributeGroup(),
              let certificate = loadTestIssuerCertificate() else { return .blocked }

        let readerAuthProfile: ReaderAuthProfile?
        do {
            readerAuthProfile = try selectedReaderAuthOption.load(from: resourceBundle)
        } catch {
            Logger.log("Failed to load ReaderAuth profile '\(selectedReaderAuthOption)': \(error)", level: .error)
            return .blocked
        }

        return .proceed(
            VerifierConfig(
                attributeRequest: attributeGroup,
                trustedIssuerCertificate: certificate,
                readerAuthProfile: readerAuthProfile
            )
        )
    }

    /// Presents an alert explaining that the selected reader-auth certificate is an unprovisioned
    /// placeholder and that verification is blocked until the build is published through the pipeline.
    private func presentNotProvisionedAlert() {
        let alert = UIAlertController(
            title: Self.notProvisionedAlertTitle,
            message: Self.notProvisionedAlertMessage,
            preferredStyle: .alert
        )
        alert.view.accessibilityIdentifier = Self.notProvisionedAlertIdentifier
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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

    /// Selects a reader-auth profile, as the drop-down menu action does. Exposed for the UI to call
    /// and for tests to drive the selection without simulating menu interaction.
    func select(readerAuthOption option: ReaderAuthProfileOption) {
        selectedReaderAuthOption = option
    }

    /// Builds the `AttributeGroup` for the currently selected attribute option.
    func buildAttributeGroup() -> AttributeGroup? {
        selectedAttributeOption.attributeGroup
    }
}
