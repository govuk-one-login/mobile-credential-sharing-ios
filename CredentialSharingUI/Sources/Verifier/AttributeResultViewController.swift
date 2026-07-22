import SharingCryptoService
import UIKit

/// Displays the verified attributes from a successful DeviceResponse validation.
class AttributeResultViewController: UIViewController {
    private let deviceResponse: DeviceResponse

    init(deviceResponse: DeviceResponse) {
        self.deviceResponse = deviceResponse
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true
        title = "Verification Result"
        setupView()
    }

    private func setupView() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.accessibilityIdentifier = "AttributeResultStackView"
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        let successLabel = makeLabel(
            text: "Document successfully Verified",
            style: .title2,
            accessibilityIdentifier: "AttributeResultTitle"
        )
        stackView.addArrangedSubview(successLabel)

        guard let documents = deviceResponse.documents else { return }

        for document in documents {
            stackView.addArrangedSubview(makeLabel(text: document.docType.rawValue, style: .headline))

            for (nameSpace, items) in document.issuerSigned.nameSpaces {
                stackView.addArrangedSubview(makeLabel(text: nameSpace, style: .subheadline, color: .secondaryLabel))

                for item in items {
                    stackView.addArrangedSubview(
                        makeLabel(text: "\(item.elementIdentifier): \(item.elementValue)", style: .body)
                    )
                }
            }
        }
    }

    private func makeLabel(
        text: String,
        style: UIFont.TextStyle,
        color: UIColor = .label,
        accessibilityIdentifier: String? = nil
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        label.accessibilityIdentifier = accessibilityIdentifier
        return label
    }
}
