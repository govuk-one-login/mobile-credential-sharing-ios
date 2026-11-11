import DesignSystem
import UIKit

/// The live QR code area for the engagement screen.
///
/// `GDSScreen` builds its `body` into views only once, so the QR slot cannot be driven by
/// swapping the view model after load. Instead `EngagementViewController` owns a single
/// `QRCodeView` instance, hosts it in both the portrait body and the landscape column, and
/// calls ``update(payload:)`` as the engagement QR is shown, hidden (grace period) and
/// refreshed on expiry — all on the same screen instance.
///
/// The view keeps a fixed square footprint (height == width) whether it shows the QR image
/// or blank space, so the body copy below it never shifts between states.
@MainActor
final class QRCodeView: UIView {
    /// The QR image view, created lazily on first non-nil payload and reused thereafter.
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = GDSLocalisedString(stringKey: "qrCodeAltText", bundle: .module).value
        imageView.accessibilityTraits = .image
        imageView.accessibilityIdentifier = QRCodeViewModel.qrImageAccessibilityIdentifier
        return imageView
    }()

    init(initialPayload: String?) throws {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "qr-code-slot"

        // Square footprint: height tracks width, matching how the aspect-fit QR image
        // (a square image) sizes itself when it fills the available width. Kept constant
        // across the QR/blank states so the body copy below does not move.
        let aspect = heightAnchor.constraint(equalTo: widthAnchor)
        aspect.priority = .required - 1
        aspect.isActive = true

        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        try update(payload: initialPayload)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the QR for a non-nil payload, or blanks the slot for a nil payload (the
    /// hidden/grace state).
    ///
    /// A nil payload is a valid state and never throws. A non-nil payload that fails to
    /// generate throws `QRCodeGenerationError`: the caller is responsible for terminating
    /// the session (a QR we cannot render is unrecoverable), rather than leaving a blank
    /// slot in place.
    func update(payload: String?) throws {
        guard let payload else {
            showBlank()
            return
        }

        imageView.image = try QRGenerator.generateQRCode(from: payload)
        imageView.isHidden = false
        imageView.accessibilityElementsHidden = false
    }

    private func showBlank() {
        imageView.image = nil
        imageView.isHidden = true
        // Hidden views are not accessibility elements, but be explicit so VoiceOver skips
        // the empty slot entirely.
        imageView.accessibilityElementsHidden = true
    }
}

/// A content view model that inserts an already-constructed `UIView` into a `GDSScreen`
/// body, letting a view controller own and later mutate that view (e.g. the live
/// ``QRCodeView``) rather than have `GDSScreen` build and freeze it.
@MainActor
struct PassthroughContentViewModel: ContentViewModel {
    typealias ViewType = PassthroughContentView

    let view: UIView

    let accessibilityIdentifier: String?
    let accessibilityTraits: UIAccessibilityTraits?
    let verticalPadding: VerticalPadding?
    let horizontalPadding: HorizontalPadding?

    init(
        view: UIView,
        verticalPadding: VerticalPadding? = .vertical(DesignSystem.Spacing.default),
        horizontalPadding: HorizontalPadding? = .horizontal(DesignSystem.Spacing.default)
    ) {
        self.view = view
        self.accessibilityIdentifier = nil
        self.accessibilityTraits = nil
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
    }

    func createUIView() -> UIView {
        view
    }
}

@MainActor
final class PassthroughContentView: UIView, ContentView {
    init(viewModel: PassthroughContentViewModel) {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
