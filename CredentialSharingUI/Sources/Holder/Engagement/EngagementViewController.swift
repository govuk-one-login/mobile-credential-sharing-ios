import DesignSystem
import SharingOrchestration
import UIKit

/// Renders the QR code screen.
///
/// Portrait uses the standard `GDSScreen` single-column vertical layout (title, QR code,
/// body copy in a scroll view). Landscape overlays a two-column layout built by
/// ``QRCodeLandscapeView``; this controller only decides which of the two is visible.
@MainActor
final class EngagementViewController: GDSScreen {
    private let qrCodeViewModel: QRCodeViewModel

    /// The landscape two-column layout. Added as a sibling of the inherited `GDSScreen`
    /// content and shown/hidden based on orientation.
    private lazy var landscapeView = QRCodeLandscapeView(viewModel: qrCodeViewModel)

    /// The inherited `GDSScreen` content views (its container stack), captured before the
    /// landscape view is added so they can be hidden in landscape. `GDSScreen`'s own stack
    /// views are not accessible across module boundaries, so we toggle the subviews it
    /// installed on `view` instead.
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

        view.addSubview(landscapeView)
        NSLayoutConstraint.activate([
            landscapeView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            landscapeView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            landscapeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            landscapeView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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

        landscapeView.isHidden = !newValue
        // Hide the inherited single-column content while the landscape layout is shown.
        portraitContentViews.forEach { $0.isHidden = newValue }
    }
}
