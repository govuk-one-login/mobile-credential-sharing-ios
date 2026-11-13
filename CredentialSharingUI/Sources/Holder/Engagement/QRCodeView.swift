import DesignSystem
import UIKit

/// The live QR code area for the engagement screen.
///
/// `GDSScreen` builds its `body` into views only once, so the QR slot cannot be driven by
/// swapping the view model after load. Instead `EngagementViewController` owns the QR views
/// (one for portrait, one for landscape — a view can only live in one hierarchy) and calls
/// ``show(image:)`` as the engagement QR is shown, hidden (grace period) and refreshed on
/// expiry.
///
/// This view only *displays* a QR image it is given; the controller generates the image
/// once and shares it between the two QR views, so the QR is not generated twice.
///
/// The view keeps a fixed square footprint (height == width) whether it shows the QR image
/// or blank space, so the body copy below it never shifts between states.
@MainActor
final class QRCodeView: UIView {
    /// Internal white padding between the QR modules and the edge of the white box, per the
    /// design. Kept white in both light and dark mode.
    static let whitePadding: CGFloat = DesignSystem.Spacing.default

    /// The white box the QR sits in. Shown only when there is a QR; the hide/grace state
    /// leaves the slot blank (no white square floating on a dark background).
    private lazy var whiteBox: UIView = {
        let box = UIView()
        box.translatesAutoresizingMaskIntoConstraints = false
        // Literal white (not `.systemBackground`) so the QR reads against white in both
        // light and dark mode.
        box.backgroundColor = .white
        box.accessibilityIdentifier = "qr-code-white-box"
        return box
    }()

    /// The QR image view, reused across refreshes.
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = GDSLocalisedString(stringKey: "qrCodeAltText", bundle: .module).value
        imageView.accessibilityTraits = .image
        imageView.accessibilityIdentifier = EngagementViewModel.qrImageAccessibilityIdentifier
        return imageView
    }()

    init(image: UIImage?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = "qr-code-slot"

        // Square footprint: height tracks width, matching how the aspect-fit QR image
        // (a square image) sizes itself when it fills the available width. Kept constant
        // across the QR/blank states so the body copy below does not move.
        let aspect = heightAnchor.constraint(equalTo: widthAnchor)
        aspect.priority = .required - 1
        aspect.isActive = true

        addSubview(whiteBox)
        whiteBox.addSubview(imageView)
        NSLayoutConstraint.activate([
            // The white box fills the whole slot so it bleeds to the edges of the area the
            // host gives us (full screen width in portrait, the 250×250 column in landscape).
            whiteBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            whiteBox.trailingAnchor.constraint(equalTo: trailingAnchor),
            whiteBox.topAnchor.constraint(equalTo: topAnchor),
            whiteBox.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Inset the QR by `whitePadding` on all sides so there is always a white border
            // between the QR modules and the edge of the box.
            imageView.leadingAnchor.constraint(equalTo: whiteBox.leadingAnchor, constant: Self.whitePadding),
            imageView.trailingAnchor.constraint(equalTo: whiteBox.trailingAnchor, constant: -Self.whitePadding),
            imageView.topAnchor.constraint(equalTo: whiteBox.topAnchor, constant: Self.whitePadding),
            imageView.bottomAnchor.constraint(equalTo: whiteBox.bottomAnchor, constant: -Self.whitePadding)
        ])

        show(image: image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Displays the given QR image (inside the white box), or blanks the slot when `nil`
    /// (the hidden/grace state — no white box shown). The caller is responsible for
    /// generating the image; this view only renders it.
    func show(image: UIImage?) {
        guard let image else {
            imageView.image = nil
            imageView.isHidden = true
            // Hide the white box too so the blank/grace state is empty, not a white square.
            whiteBox.isHidden = true
            // Hidden views are not accessibility elements, but be explicit so VoiceOver
            // skips the empty slot entirely.
            imageView.accessibilityElementsHidden = true
            return
        }

        imageView.image = image
        imageView.isHidden = false
        imageView.accessibilityElementsHidden = false
        whiteBox.isHidden = false
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
    init(viewModel _: PassthroughContentViewModel) {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
