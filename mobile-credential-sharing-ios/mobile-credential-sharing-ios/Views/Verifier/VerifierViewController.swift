import CredentialSharingUI
import Security
import SharingCryptoService
import SharingOrchestration
import UIKit

class VerifierViewController: UIViewController {
    static let option1Identifier = "Option1Button"
    static let option2Identifier = "Option2Button"
    static let verifyCredentialIdentifier = "VerifyCredentialButton"

    var selectedOption: Int?

    private let option1Button = UIButton(type: .system)
    private let option2Button = UIButton(type: .system)
    private let verifyButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        restorationIdentifier = "VerifierViewController"
        title = "Verifier"
        navigationItem.largeTitleDisplayMode = .always
        setupView()
    }

    private func setupView() {
        option1Button.setTitle("Photo and Age Over 21", for: .normal)
        option1Button.accessibilityIdentifier = VerifierViewController.option1Identifier
        option1Button.addTarget(self, action: #selector(option1Tapped), for: .touchUpInside)
        option1Button.translatesAutoresizingMaskIntoConstraints = false

        option2Button.setTitle("Name + Title (Retain) and Age Over 23", for: .normal)
        option2Button.accessibilityIdentifier = VerifierViewController.option2Identifier
        option2Button.addTarget(self, action: #selector(option2Tapped), for: .touchUpInside)
        option2Button.translatesAutoresizingMaskIntoConstraints = false

        verifyButton.setTitle("Verify Credential", for: .normal)
        verifyButton.accessibilityIdentifier = VerifierViewController.verifyCredentialIdentifier
        verifyButton.addTarget(self, action: #selector(verifyCredentialTapped), for: .touchUpInside)
        verifyButton.translatesAutoresizingMaskIntoConstraints = false

        let optionsStack = UIStackView(arrangedSubviews: [option1Button, option2Button])
        optionsStack.axis = .vertical
        optionsStack.spacing = 16
        optionsStack.alignment = .center
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(optionsStack)
        view.addSubview(verifyButton)

        NSLayoutConstraint.activate([
            optionsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            optionsStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            optionsStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            optionsStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            verifyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            verifyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])

        updateSelection()
    }

    @objc private func option1Tapped() {
        selectedOption = 1
        updateSelection()
    }

    @objc private func option2Tapped() {
        selectedOption = 2
        updateSelection()
    }

    private func updateSelection() {
        option1Button.configuration = buttonConfiguration(
            title: "Photo and Age Over 21",
            selected: selectedOption == 1
        )
        option2Button.configuration = buttonConfiguration(
            title: "Name + Title (Retain) and Age Over 23",
            selected: selectedOption == 2
        )
    }

    private func buttonConfiguration(title: String, selected: Bool) -> UIButton.Configuration {
        var config = selected ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        config.title = title
        return config
    }

    @objc private func verifyCredentialTapped() {
        guard let attributeGroup = buildAttributeGroup(),
              let certificate = loadTestIssuerCertificate() else { return }
        let config = VerifierConfig(
            attributeRequest: attributeGroup,
            trustedIssuerCertificate: certificate
        )
        let journeyVC = VerifierContainerNavigation(config: config)
        present(journeyVC, animated: true)
    }

    /// Loads a self-signed test certificate for development purposes.
    /// In production, the host app provides the real issuer root CA.
    private func loadTestIssuerCertificate() -> SecCertificate? {
        // A valid self-signed EC P-256 certificate (CN=Test Issuer) for test/demo use.
        // Replace with a real issuer root CA in production integration.
        // swiftlint:disable:next line_length
        let base64DER = "MIIBgDCCASegAwIBAgIUVOEboNCA04tyVsELHWT+C9XNYpMwCgYIKoZIzj0EAwIwFjEUMBIGA1UEAwwLVGVzdCBJc3N1ZXIwHhcNMjYwODE4MTAxNDIwWhcNMzYwODE1MTAxNDIwWjAWMRQwEgYDVQQDDAtUZXN0IElzc3VlcjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABGMSAO8t+HOpxUBMgVKtL8rW2TXLAUwLICd8C1sB1jr1npySabw0Ry1Fhjz4zkQXmXvJMxrhEg5FOeG1DNzI33ajUzBRMB0GA1UdDgQWBBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAfBgNVHSMEGDAWgBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIDgfVsLSvrcafPDOwNpmMAYSdlxbADGcbDrKAiZ0SSeYAiAwai384arQMjr5Ezw0FBguft578i+vWikUoKtvD1Fe7A=="
        guard let certData = Data(base64Encoded: base64DER) else { return nil }
        return SecCertificateCreateWithData(nil, certData as CFData)
    }

    func buildAttributeGroup() -> AttributeGroup? {
        switch selectedOption {
        case 1:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .portrait, intentToRetain: false),
                    .init(attribute: .ageOver(21), intentToRetain: false)
                ]
            )
        case 2:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .givenName, intentToRetain: true),
                    .init(attribute: .ageOver(23), intentToRetain: false)
                ],
                gbMdlAttributes: [
                    .init(attribute: .title, intentToRetain: true)
                ]
            )
        default:
            return nil
        }
    }
}
