import DesignSystem
import SharingOrchestration
import UIKit

/// Renders the QR code screen.
///
/// Portrait uses the standard `GDSScreen` single-column vertical layout (title, QR code,
/// body copy in a scroll view). Landscape overlays a two-column layout built by
/// ``QRCodeLandscapeView``; this controller decides which of the two is visible and
/// refreshes the QR in place when the engagement expires.
@MainActor
final class EngagementViewController: GDSScreen {
    var qrCodeViewModel: QRCodeViewModel

    private let orchestrator: HolderOrchestratorProtocol

    /// The portrait and landscape QR views. Separate instances (a view can only live in one
    /// view hierarchy), both refreshed together so the QR stays in sync across orientations.
    private let portraitQRView: QRCodeView
    private let landscapeQRView: QRCodeView

    /// The landscape two-column layout. Added as a sibling of the inherited `GDSScreen`
    /// content and shown/hidden based on orientation.
    private lazy var landscapeView = QRCodeLandscapeView(
        viewModel: qrCodeViewModel,
        qrCodeView: landscapeQRView
    )

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
        self.orchestrator = orchestrator
        self.portraitQRView = QRCodeView(
            orchestrator: orchestrator,
            initialPayload: presentation.qrPayload
        )
        self.landscapeQRView = QRCodeView(
            orchestrator: orchestrator,
            initialPayload: presentation.qrPayload
        )
        self.qrCodeViewModel = QRCodeViewModel(
            presentation: presentation,
            orchestrator: orchestrator,
            qrCodeView: portraitQRView,
            analyticsService: analyticsService,
            onCancel: onCancel
        )
        super.init(viewModel: qrCodeViewModel)
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

    /// Refreshes the on-screen QR code with a new presentation without rebuilding the
    /// screen. Called when the orchestrator re-enters `.presentingEngagement` for the same
    /// screen instance — showing a new QR on expiry, or blanking it during the hide/grace
    /// window (nil payload). Keeping the same instance avoids growing the navigation stack
    /// and preserves focus / scroll position.
    func refresh(with presentation: EngagementPresentation) {
        loadViewIfNeeded()
        portraitQRView.update(payload: presentation.qrPayload)
        landscapeQRView.update(payload: presentation.qrPayload)
    }
}
