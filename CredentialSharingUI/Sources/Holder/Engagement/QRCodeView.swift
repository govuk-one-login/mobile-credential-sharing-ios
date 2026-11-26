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
    /// Width of the border drawn around the white box, per the design (1px = 1pt).
    static let borderWidth: CGFloat = 1

    /// The border colour: Grey 8 in light mode, white in dark mode.
    static let borderColor = UIColor(
        light: DesignSystem.Color.Base.grey8,
        dark: DesignSystem.Color.Base.white
    )

    /// The white box the QR sits in, with rounded corners. The 4-module quiet zone between the
    /// QR modules and the border is part of the QR image itself (see `QRGenerator`), so it
    /// stays proportional to the QR at any size. Shown only when there is a QR; the
    /// hide/grace state leaves the slot blank (no white square or border floating on a dark
    /// background).
    private lazy var whiteBox: UIView = {
        let box = UIView()
        box.translatesAutoresizingMaskIntoConstraints = false
        // Literal white (not `.systemBackground`) so the QR reads against white in both
        // light and dark mode.
        box.backgroundColor = .white
        box.accessibilityIdentifier = "qr-code-white-box"
        box.layer.cornerRadius = DesignSystem.CornerRadius.small
        // Clip the image to the rounded shape. The image has its own opaque white quiet zone
        // with square corners, which would otherwise stick out past the curve (visible against
        // the dark background in dark mode).
        box.layer.masksToBounds = true
        return box
    }()

    /// The border, drawn as an overlay above the image. A layer border on the white box would
    /// be painted over by the image (a subview draws above its parent's border) wherever the
    /// image meets the rounded corners.
    private lazy var borderView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.accessibilityIdentifier = "qr-code-border"
        view.layer.cornerRadius = DesignSystem.CornerRadius.small
        view.layer.borderWidth = Self.borderWidth
        return view
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
        // Added last so the border draws above the image.
        whiteBox.addSubview(borderView)
        NSLayoutConstraint.activate([
            // The white box fills the whole slot, i.e. the area the host gives us (the text
            // column width in portrait, the 250×250 column in landscape).
            whiteBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            whiteBox.trailingAnchor.constraint(equalTo: trailingAnchor),
            whiteBox.topAnchor.constraint(equalTo: topAnchor),
            whiteBox.bottomAnchor.constraint(equalTo: bottomAnchor),

            borderView.leadingAnchor.constraint(equalTo: whiteBox.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: whiteBox.trailingAnchor),
            borderView.topAnchor.constraint(equalTo: whiteBox.topAnchor),
            borderView.bottomAnchor.constraint(equalTo: whiteBox.bottomAnchor),

            // Inset the image by the border width so the 4-module quiet zone, which is part
            // of the image, is measured from the inner edge of the border.
            imageView.leadingAnchor.constraint(equalTo: whiteBox.leadingAnchor, constant: Self.borderWidth),
            imageView.trailingAnchor.constraint(equalTo: whiteBox.trailingAnchor, constant: -Self.borderWidth),
            imageView.topAnchor.constraint(equalTo: whiteBox.topAnchor, constant: Self.borderWidth),
            imageView.bottomAnchor.constraint(equalTo: whiteBox.bottomAnchor, constant: -Self.borderWidth)
        ])

        updateBorderColor()
        show(image: image)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // `CALayer.borderColor` is a fixed `CGColor`, so the dynamic colour must be
        // re-resolved when light/dark mode changes.
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }

    private func updateBorderColor() {
        borderView.layer.borderColor = Self.borderColor.resolvedColor(with: traitCollection).cgColor
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
