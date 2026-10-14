import SafariServices
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
class ConsentViewController: UIViewController {
    private let presentation: ConsentPresentation
    private let orchestrator: HolderOrchestratorProtocol
    private var isBusy = false {
        didSet { buttons.forEach { $0.isEnabled = !isBusy } }
    }
    private let container: HolderContainerProtocol

    var buttons: [UIButton] = []

    /// The scrollable text view listing the attributes to be shared. Occupies
    /// the top region of the screen.
    let attributesTextView = UITextView()

    /// The text view pinned to the bottom (above the action buttons) carrying
    /// the organisation sentence (AC6) and the privacy-policy link (AC5).
    let footerTextView = UITextView()

    /// Bordered box that visually contains both the attributes list and the
    /// footer (org sentence + privacy link).
    private let contentBox = UIView()

    /// Base text attributes shared by the attributes list and the footer.
    private var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ]
    }

    init(presentation: ConsentPresentation,
         orchestrator: HolderOrchestratorProtocol,
         container: HolderContainerProtocol,
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
        self.container = container
        super.init(nibName: nil, bundle: nil)
        container.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isBusy = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        navigationItem.hidesBackButton = true

        setupTitle()
        setupButtons()
        setupContentBox()
        setupFooterTextView()
        setupAttributesTextView()
    }
    
    private func setupTitle() {
        let titleLabel = UILabel()
        titleLabel.text = "Confirm the credential attributes to share"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    /// The bordered box filling the region between the title and the action
    /// buttons. Both text views live inside it so the footer stays visually
    /// within the border.
    private func setupContentBox() {
        contentBox.layer.borderWidth = 1
        contentBox.layer.borderColor = UIColor.systemGray4.cgColor
        contentBox.layer.cornerRadius = 8
        contentBox.clipsToBounds = true
        contentBox.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(contentBox)

        NSLayoutConstraint.activate([
            contentBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            contentBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90)
        ])
    }
    
    /// Pinned to the bottom of the content box: the organisation sentence
    /// and the clickable privacy-policy link. Set up before the attributes
    /// text view so the latter can anchor its bottom to the top of this view.
    private func setupFooterTextView() {
        footerTextView.attributedText = formatFooter()
        footerTextView.isEditable = false
        footerTextView.isScrollEnabled = false
        footerTextView.isSelectable = true
        footerTextView.delegate = self
        footerTextView.backgroundColor = .clear
        footerTextView.setContentCompressionResistancePriority(.required, for: .vertical)
        footerTextView.setContentHuggingPriority(.required, for: .vertical)
        footerTextView.translatesAutoresizingMaskIntoConstraints = false

        contentBox.addSubview(footerTextView)

        NSLayoutConstraint.activate([
            footerTextView.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: 8),
            footerTextView.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -8),
            footerTextView.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -8)
        ])
    }

    /// The scrollable attributes list filling the top of the content box, down
    /// to the pinned footer.
    private func setupAttributesTextView() {
        attributesTextView.attributedText = formatAttributes()
        attributesTextView.isEditable = false
        attributesTextView.isScrollEnabled = true
        attributesTextView.isSelectable = true
        attributesTextView.backgroundColor = .clear
        attributesTextView.translatesAutoresizingMaskIntoConstraints = false

        contentBox.addSubview(attributesTextView)

        NSLayoutConstraint.activate([
            attributesTextView.topAnchor.constraint(equalTo: contentBox.topAnchor, constant: 8),
            attributesTextView.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: 8),
            attributesTextView.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -8),
            attributesTextView.bottomAnchor.constraint(equalTo: footerTextView.topAnchor, constant: -8)
        ])
    }
    
    private func setupButtons() {
        let acceptButton = UIButton(type: .system)
        acceptButton.setTitle("Accept", for: .normal)
        acceptButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        acceptButton.backgroundColor = .systemGreen
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.layer.cornerRadius = 8
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.addTarget(self, action: #selector(acceptButtonTapped), for: .touchUpInside)

        let denyButton = UIButton(type: .system)
        denyButton.setTitle("Deny", for: .normal)
        denyButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        denyButton.backgroundColor = .systemRed
        denyButton.setTitleColor(.white, for: .normal)
        denyButton.layer.cornerRadius = 8
        denyButton.translatesAutoresizingMaskIntoConstraints = false
        denyButton.addTarget(self, action: #selector(denyButtonTapped), for: .touchUpInside)

        buttons = [acceptButton, denyButton]
        buttons.forEach { view.addSubview($0) }
        
        NSLayoutConstraint.activate([
            acceptButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            acceptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            acceptButton.heightAnchor.constraint(equalToConstant: 50),
            acceptButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            
            denyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            denyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            denyButton.heightAnchor.constraint(equalToConstant: 50),
            denyButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10)
        ])
    }

    // MARK: - Presentation Formatting

    /// Builds the top (scrollable) section listing the attributes to be shared.
    ///
    /// The list is driven entirely from the ``ConsentPresentation`` model
    /// (derived from the filtered `IssuerSigned`), so it shows only attributes
    /// that will actually be included in the `DeviceResponse`each with its `intentToRetain` flag
    /// `age_over_NN` attestations appear automatically because they are already
    /// present in the filtered data
    ///
    /// Attributes are grouped by namespace and sorted deterministically
    /// (namespaces alphabetically, then attribute labels within each) so the
    /// display order is stable regardless of the order they arrive from the
    /// filter's `retention` map.
    private func formatAttributes() -> NSAttributedString {
        let result = NSMutableAttributedString()

        let groupedByNamespace = Dictionary(grouping: presentation.attributes, by: \.namespace)

        for namespace in groupedByNamespace.keys.sorted() {
            result.append(NSAttributedString(string: "\(namespace)\n", attributes: baseAttributes))

            let attributes = (groupedByNamespace[namespace] ?? [])
                .sorted { $0.displayLabel < $1.displayLabel }

            for attribute in attributes {
                let retention = attribute.intentToRetain
                    ? "will be kept by the verifier"
                    : "will not be kept"
                let line = "  • \(attribute.displayLabel) — \(retention)\n"
                result.append(NSAttributedString(string: line, attributes: baseAttributes))
            }
            result.append(NSAttributedString(string: "\n", attributes: baseAttributes))
        }

        return result
    }

    /// Builds the bottom (pinned) section: the organisation sentence using
    /// period-normalised `dvsName` and the privacy-policy URI rendered as
    /// a tappable link
    private func formatFooter() -> NSAttributedString {
        let result = NSMutableAttributedString()

        let normalisedName = normaliseDvsName(presentation.dvsName)
        let orgSentence = "The person doing the check is using an approved app powered by \(normalisedName).\n\n"
        result.append(NSAttributedString(string: orgSentence, attributes: baseAttributes))

        var linkAttributes = baseAttributes
        linkAttributes[.link] = presentation.privacyPolicyURL
        result.append(NSAttributedString(string: "Privacy policy", attributes: linkAttributes))

        return result
    }

    /// Strips any trailing period(s) from the raw `dvsName` so the caller can
    /// append exactly one. e.g. both `"Yoti Ltd"` and `"Yoti Ltd."` yield
    /// `"Yoti Ltd"`
    func normaliseDvsName(_ name: String) -> String {
        var trimmed = name
        while trimmed.hasSuffix(".") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed
    }

    @objc private func acceptButtonTapped() {
        isBusy = true
        orchestrator.userDidTapApprove()
    }

    @objc private func denyButtonTapped() {
        isBusy = true
        Logger.log("Deny button tapped — session state: awaitingUserConsent")
        
        let alert = UIAlertController(
            title: nil,
            message: "Are you sure you want to deny this request?",
            preferredStyle: .alert
        )
        
        let denyAction = UIAlertAction(title: "Deny", style: .destructive) { [weak self] _ in
            self?.confirmDenial()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.handleCancellation()
        }
        
        alert.addAction(denyAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    func confirmDenial() {
        orchestrator.userDidTapDeny()
    }

    internal func handleCancellation() {
        isBusy = false
        Logger.log("Denial cancelled — session state: awaitingUserConsent")
    }
}

// MARK: - UITextViewDelegate (Open privacy-policy link in embedded web view)

extension ConsentViewController: UITextViewDelegate {
    func textView(
        _: UITextView,
        shouldInteractWith url: URL,
        in _: NSRange,
        interaction _: UITextItemInteraction
    ) -> Bool {
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true)
        // Return false so UITextView does not also open Safari externally.
        return false
    }
}

extension ConsentViewController: HolderContainerDelegate {
    func operationDidFailRecoverably() {
        isBusy = false
    }
}
