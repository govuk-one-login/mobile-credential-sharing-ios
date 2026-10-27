import GDSAnalytics
import GDSCommon
import Logging
import SafariServices
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

enum ConsentAnalytics {
    // are we hardcoding screenIDs? Ask team
    static let screenID = "ac1f2e03-2b4e-4804-8c16-2d18c37b0f9e"
    static let readAboutButtonText = "Read about DVS and their privacy notice"
    static let agreeButtonText = "Agree and share details"
    static let cancelButtonText = "Cancel and go back to documents"
}

@MainActor
class ConsentViewController: UIViewController {
    private static let margin: CGFloat = 16
    private let presentation: ConsentPresentation
    private let content: ConsentContent
    private let orchestrator: HolderOrchestratorProtocol
    private let analyticsService: AnalyticsService?
    private var isBusy = false {
        didSet { buttons.forEach { $0.isEnabled = !isBusy } }
    }
    private(set) var container: HolderContainerProtocol

    let agreeButton = RoundedButton()
    let cancelButton = SecondaryButton()
    let readAboutButton = SecondaryButton()
    var buttons: [UIButton] { [agreeButton, cancelButton] }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let bottomStack = UIStackView()
    private let pinnedBottomStack = UIStackView()
    private(set) var isBottomContentPinned = true

    init(presentation: ConsentPresentation,
         orchestrator: HolderOrchestratorProtocol,
         container: HolderContainerProtocol,
         analyticsService: AnalyticsService? = nil
    ) {
        self.presentation = presentation
        self.content = ConsentContent(presentation: presentation)
        self.orchestrator = orchestrator
        self.container = container
        self.analyticsService = analyticsService
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

        setupScrollAndPinnedLayout()
        setupBottomButtons()
        populateContent()
        trackScreenView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBottomContentPlacement()
    }

    // MARK: - Layout

    private func setupScrollAndPinnedLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = Self.margin
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: Self.margin, leading: Self.margin,
                                                      bottom: Self.margin, trailing: Self.margin)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        // An empty stack has zero height, so when the buttons move into the scroll content the scroll view fills the screen.
        pinnedBottomStack.axis = .vertical
        pinnedBottomStack.isLayoutMarginsRelativeArrangement = true
        pinnedBottomStack.directionalLayoutMargins = .init(top: Self.margin, leading: Self.margin,
                                                           bottom: Self.margin, trailing: Self.margin)
        pinnedBottomStack.backgroundColor = .systemBackground
        pinnedBottomStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(pinnedBottomStack)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pinnedBottomStack.topAnchor),

            pinnedBottomStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pinnedBottomStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pinnedBottomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func setupBottomButtons() {
        agreeButton.setTitle(content.agreeButtonTitle, for: .normal)
        agreeButton.accessibilityIdentifier = "ConsentAgreeButton"
        agreeButton.addAction(UIAction { [weak self] _ in self?.acceptButtonTapped() }, for: .touchUpInside)

        cancelButton.color = .gdsRed
        cancelButton.setTitle(ConsentContent.cancelButtonTitle, for: .normal)
        cancelButton.accessibilityIdentifier = "ConsentCancelButton"
        cancelButton.addAction(UIAction { [weak self] _ in self?.cancelButtonTapped() }, for: .touchUpInside)

        bottomStack.axis = .vertical
        bottomStack.spacing = Self.margin / 2
        bottomStack.addArrangedSubview(agreeButton)
        bottomStack.addArrangedSubview(cancelButton)
        pinnedBottomStack.addArrangedSubview(bottomStack)
    }

    private func populateContent() {
        contentStack.addArrangedSubview(makeLabel(ConsentContent.title,
                                                  font: UIFont(style: .largeTitle, weight: .bold),
                                                  isHeader: true))
        contentStack.addArrangedSubview(makeLabel(content.organisationSentence, font: .body))

        readAboutButton.setTitle(content.readAboutButtonTitle, for: .normal)
        readAboutButton.contentHorizontalAlignment = .leading
        readAboutButton.accessibilityIdentifier = "ConsentReadAboutButton"
        readAboutButton.addAction(UIAction { [weak self] _ in self?.readAboutButtonTapped() }, for: .touchUpInside)
        contentStack.addArrangedSubview(readAboutButton)

        contentStack.addArrangedSubview(makeLabel(ConsentContent.whatYoullShareHeading,
                                                  font: UIFont(style: .title2, weight: .bold),
                                                  isHeader: true))
        contentStack.addArrangedSubview(makeCard())
    }

    private func makeCard() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Self.margin
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: Self.margin, leading: Self.margin,
                                               bottom: Self.margin, trailing: Self.margin)
        stack.layer.borderWidth = 1
        stack.layer.borderColor = UIColor.systemGray4.cgColor
        stack.layer.cornerRadius = 8

        stack.addArrangedSubview(makeLabel(content.summary, font: .bodyBold))
        for section in content.sections {
            if let heading = section.heading {
                stack.addArrangedSubview(makeLabel(heading, font: .body))
            }
            section.items.forEach { stack.addArrangedSubview(makeLabel($0, font: .body)) }
            if let footnote = section.footnote {
                stack.addArrangedSubview(makeLabel(footnote, font: .body))
            }
        }
        return stack
    }

    private func makeLabel(_ text: String, font: UIFont, isHeader: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        if isHeader { label.accessibilityTraits.insert(.header) }
        return label
    }

    // MARK: - Bottom pinning

    // swiftlint:disable:next type_contents_order
    static func shouldPinBottomContent(bottomContentHeight: CGFloat, viewportHeight: CGFloat) -> Bool {
        bottomContentHeight <= viewportHeight / 3
    }

    private func updateBottomContentPlacement() {
        let width = max(view.safeAreaLayoutGuide.layoutFrame.width - Self.margin * 2, 0)
        let fitted = bottomStack.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let shouldPin = Self.shouldPinBottomContent(bottomContentHeight: fitted.height + Self.margin * 2,
                                                    viewportHeight: view.bounds.height)
        guard shouldPin != isBottomContentPinned else { return }
        isBottomContentPinned = shouldPin
        (shouldPin ? pinnedBottomStack : contentStack).addArrangedSubview(bottomStack)
    }

    // MARK: - Analytics

    private func trackScreenView() {
        analyticsService?.trackScreenEvent(
            ScreenViewEventName.screenView,
            title: ConsentContent.title,
            screenClass: .uiController,
            screenID: ConsentAnalytics.screenID
        )
    }

    private func trackButton(_ text: String) {
        analyticsService?.trackButtonEvent(ButtonEvent(textKey: text))
    }

    @objc private func acceptButtonTapped() {
        isBusy = true
        trackButton(ConsentAnalytics.agreeButtonText)
        orchestrator.userDidTapApprove()
    }

    @objc private func readAboutButtonTapped() {
        trackButton(ConsentAnalytics.readAboutButtonText)
    }

    @objc private func cancelButtonTapped() {
        trackButton(ConsentAnalytics.cancelButtonText)
    }

    // Not shown on screen - get permission to delete.
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

// Not shown on screen; retained for the More About DVS work (DCMAW-23711).
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
    func consentRetryAvailable() {
        isBusy = false
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

private final class PreviewOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    func startPresentation() {}
    func resolve(_ missingPrerequisite: MissingPrerequisite) {}
    func userDidTapApprove() {}
    func userDidTapDeny() {}
    func userDidTapCancel() {}
    func userDidConfirmCancel() {}
}

private final class PreviewContainer: HolderContainerProtocol {
    weak var delegate: HolderContainerDelegate?
}

private struct ConsentViewControllerPreview: UIViewControllerRepresentable {
    let attributes: [ConsentAttribute]

    func makeUIViewController(context: Context) -> UINavigationController {
        let presentation = ConsentPresentation(
            dvsName: "Yoti Ltd.",
            documentType: DocumentType(displayLabel: "Driving Licence", documentIcon: UIImage()),
            attributes: attributes,
            privacyPolicyURL: URL(string: "https://example.com/privacy")!
        )
        let viewController = ConsentViewController(
            presentation: presentation,
            orchestrator: PreviewOrchestrator(),
            container: PreviewContainer()
        )
        return UINavigationController(rootViewController: viewController)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

#Preview {
    ConsentViewControllerPreview(attributes: [
        ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "Name", intentToRetain: true),
        ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "Photo", intentToRetain: false)
    ])
}

#endif
