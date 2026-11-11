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

    /// Throws `QRCodeGenerationError` if the initial QR payload cannot be rendered. The
    /// caller (`HolderNavigationController`) catches this and terminates the session, rather
    /// than presenting a screen with an unrecoverable blank QR.
    init(
        presentation: EngagementPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) throws {
        // Generate the QR once and share the image between the portrait and landscape views.
        let image = try Self.makeImage(for: presentation.qrPayload)
        self.portraitQRView = QRCodeView(image: image)
        self.landscapeQRView = QRCodeView(image: image)
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
    ///
    /// Generates the QR once and shares the image between both QR views. Throws
    /// `QRCodeGenerationError` if a (non-nil) refreshed payload cannot be rendered, so the
    /// caller can terminate the session rather than leave a stale/blank QR.
    func refresh(with presentation: EngagementPresentation) throws {
        loadViewIfNeeded()
        let image = try Self.makeImage(for: presentation.qrPayload)
        portraitQRView.show(image: image)
        landscapeQRView.show(image: image)
    }

    /// Generates the QR image for a payload, or returns `nil` for a nil payload (the valid
    /// hidden/grace state). Non-nil payloads that fail to generate throw.
    private static func makeImage(for payload: String?) throws -> UIImage? {
        guard let payload else { return nil }
        return try QRGenerator.generateQRCode(from: payload)
    }
}
