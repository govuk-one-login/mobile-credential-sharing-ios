import DesignSystem
import SharingOrchestration
import UIKit

/// Renders the QR code screen.
///
/// Portrait uses the standard `GDSScreen` single-column vertical layout (title, QR code,
/// body copy in a scroll view). Landscape satisfies the ticket's landscape requirements by
/// overlaying a two-column layout:
/// - Column 1: title and body copy. Scrollable when the text does not fit.
/// - Column 2: the QR code at a fixed 250×250 size. Not scrollable.
@MainActor
final class EngagementViewController: GDSScreen {
    private let qrCodeViewModel: QRCodeViewModel

    /// Container for the landscape two-column layout. Added as a sibling of the inherited
    /// `GDSScreen` content and shown/hidden based on orientation.
    private lazy var landscapeContainer: UIView = makeLandscapeContainer()

    /// The inherited `GDSScreen` content views (its container stack), captured before the
    /// landscape container is added so they can be hidden in landscape. `GDSScreen`'s own
    /// stack views are not accessible across module boundaries, so we toggle the subviews
    /// it installed on `view` instead.
    private var portraitContentViews: [UIView] = []

    /// Tracks the last applied orientation so layout work only runs when it actually
    /// changes. `nil` until the first layout pass applies a value.
    private var isLandscape: Bool?

    init(
        presentation: EngagementPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        let viewModel = QRCodeViewModel(
            presentation: presentation,
            orchestrator: orchestrator,
            analyticsService: analyticsService,
            onCancel: onCancel
        )
        self.qrCodeViewModel = viewModel
        super.init(viewModel: viewModel)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Capture the GDSScreen-installed content before adding the landscape overlay.
        portraitContentViews = view.subviews

        view.addSubview(landscapeContainer)
        NSLayoutConstraint.activate([
            landscapeContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            landscapeContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            landscapeContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            landscapeContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Drive the layout from the view's actual bounds so it is correct for the initial
        // layout, device rotation, and modal-sheet presentation (where the transition size
        // does not always reflect the sheet's own bounds).
        applyLayout(isLandscape: view.bounds.width > view.bounds.height)
    }

    private func applyLayout(isLandscape newValue: Bool) {
        guard isLandscape != newValue else { return }
        isLandscape = newValue

        landscapeContainer.isHidden = !newValue
        // Hide the inherited single-column content while the landscape layout is shown.
        portraitContentViews.forEach { $0.isHidden = newValue }
    }
}

// MARK: - Landscape two-column layout
private extension EngagementViewController {
    func makeLandscapeContainer() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = qrCodeViewModel.backgroundColor

        let textColumn = makeTextColumn()
        let qrColumn = makeQRColumn()

        container.addSubview(textColumn)
        container.addSubview(qrColumn)

        NSLayoutConstraint.activate([
            // Column 1: title + body copy. Takes the leading portion and may scroll.
            textColumn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textColumn.topAnchor.constraint(equalTo: container.topAnchor),
            textColumn.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            // Column 2: QR code, fixed size, not scrollable, trailing side.
            qrColumn.leadingAnchor.constraint(equalTo: textColumn.trailingAnchor),
            qrColumn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            qrColumn.topAnchor.constraint(equalTo: container.topAnchor),
            qrColumn.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            // The QR column hugs its fixed content; the text column takes the rest.
            qrColumn.widthAnchor.constraint(
                greaterThanOrEqualToConstant:
                    QRCodeViewModel.landscapeQRDimension + DesignSystem.Spacing.default * 2
            )
        ])

        return container
    }

    /// Column 1 — scrollable title and body text.
    func makeTextColumn() -> UIView {
        let stack = UIStackView(
            arrangedSubviews: [
                qrCodeViewModel.titleContent.createUIView(),
                qrCodeViewModel.bodyContent.createUIView()
            ]
        )
        stack.axis = .vertical
        stack.spacing = DesignSystem.Spacing.default
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: DesignSystem.Spacing.default,
            leading: DesignSystem.Spacing.default,
            bottom: DesignSystem.Spacing.default,
            trailing: DesignSystem.Spacing.default
        )

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.accessibilityIdentifier = "qr-code-landscape-text-scroll-view"
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // Pin the content width to the scroll view so it only scrolls vertically.
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        return scrollView
    }

    /// Column 2 — the QR code at a fixed 250×250 size, vertically centred and not scrollable.
    func makeQRColumn() -> UIView {
        let column = UIView()
        column.translatesAutoresizingMaskIntoConstraints = false
        column.accessibilityIdentifier = "qr-code-landscape-qr-column"

        let qrView = qrCodeViewModel.makeLandscapeQRContent()
            .first?
            .createUIView() ?? UIView()
        qrView.translatesAutoresizingMaskIntoConstraints = false

        column.addSubview(qrView)
        NSLayoutConstraint.activate([
            qrView.centerXAnchor.constraint(equalTo: column.centerXAnchor),
            qrView.centerYAnchor.constraint(equalTo: column.centerYAnchor),
            qrView.leadingAnchor.constraint(
                greaterThanOrEqualTo: column.leadingAnchor,
                constant: DesignSystem.Spacing.default
            ),
            qrView.trailingAnchor.constraint(
                lessThanOrEqualTo: column.trailingAnchor,
                constant: -DesignSystem.Spacing.default
            )
        ])

        // The ticket requires the QR code to be exactly 250×250 in landscape. Apply the
        // fixed sizing only to the generated QR image — the loading-indicator fallback
        // keeps its intrinsic size centred within the reserved column.
        if qrView.accessibilityIdentifier == QRCodeViewModel.qrImageAccessibilityIdentifier {
            NSLayoutConstraint.activate([
                qrView.widthAnchor.constraint(equalToConstant: QRCodeViewModel.landscapeQRDimension),
                qrView.heightAnchor.constraint(equalToConstant: QRCodeViewModel.landscapeQRDimension)
            ])
        }

        return column
    }
}
