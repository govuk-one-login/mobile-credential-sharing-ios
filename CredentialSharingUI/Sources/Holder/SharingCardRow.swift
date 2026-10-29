import DesignSystem
import UIKit

// MARK: - SharingCardRowViewModel

/// A single row of the "Agree to Share" card.
@MainActor
struct SharingCardRowViewModel: ContentViewModel {
    typealias ViewType = SharingCardRowView

    /// Fixed size of the leading document image, per design.
    static let imageSize = CGSize(width: 70, height: 50)

    let title: GDSLocalisedString
    let isGrey: Bool
    let leadingImage: UIImage?
    let accessibilityIdentifier: String?
    let accessibilityTraits: UIAccessibilityTraits?
    let verticalPadding: VerticalPadding?
    let horizontalPadding: HorizontalPadding?

    init(
        title: GDSLocalisedString,
        isGrey: Bool,
        leadingImage: UIImage? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityTraits: UIAccessibilityTraits? = nil
    ) {
        self.title = title
        self.isGrey = isGrey
        self.leadingImage = leadingImage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityTraits = accessibilityTraits
        // Rows span the full width of the card; all insets are applied inside
        // the view so text alignment is consistent across every row.
        self.verticalPadding = .vertical(0)
        self.horizontalPadding = .horizontal(0)
    }
}

// MARK: - SharingCardRowView

@MainActor
final class SharingCardRowView: UIView, ContentView {
    /// Standard inset from the card border: used for vertical padding and for
    /// the leading image's position.
    private static let standardInset = DesignSystem.Spacing.default
    /// Where text starts, measured from the card border. Doubled so text lines
    /// up down the whole card (image rows put the image at `standardInset` and
    /// the text flows after it).
    private static let textInset = DesignSystem.Spacing.default * 2 // 32
    private static let imageTextSpacing = DesignSystem.Spacing.default

    init(viewModel: SharingCardRowViewModel) {
        super.init(frame: .zero)

        if viewModel.isGrey {
            backgroundColor = UIColor(
                light: DesignSystem.Color.Base.grey4,
                dark: DesignSystem.Color.Base.charcoal2
            )
        }

        isAccessibilityElement = true
        accessibilityLabel = viewModel.title.value
        accessibilityIdentifier = viewModel.accessibilityIdentifier
        if let traits = viewModel.accessibilityTraits {
            accessibilityTraits = traits
        }

        let label = makeLabel(for: viewModel.title)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Self.imageTextSpacing
        stack.isLayoutMarginsRelativeArrangement = true
        // With an image the image sits at the standard inset and the text flows
        // after it; without one the text itself starts at the deeper inset.
        let leading = viewModel.leadingImage == nil ? Self.textInset : Self.standardInset
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Self.standardInset,
            leading: leading,
            bottom: Self.standardInset,
            trailing: Self.standardInset
        )

        if let image = viewModel.leadingImage {
            stack.addArrangedSubview(makeImageView(image))
        }
        stack.addArrangedSubview(label)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeLabel(for title: GDSLocalisedString) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignSystem.Font.Base.body
        label.textColor = DesignSystem.Color.Text.primary
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)

        if let attributed = title.attributedValue {
            // The attributed header only styles its bold segments; apply the
            // body font to any range without one so all text is the same size.
            let styled = NSMutableAttributedString(attributedString: attributed)
            styled.enumerateAttribute(.font, in: NSRange(location: 0, length: styled.length)) { value, range, _ in
                if value == nil {
                    styled.addAttribute(.font, value: DesignSystem.Font.Base.body, range: range)
                }
            }
            label.attributedText = styled
        } else {
            label.text = title.value
        }
        return label
    }

    private func makeImageView(_ image: UIImage) -> UIImageView {
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: SharingCardRowViewModel.imageSize.width),
            imageView.heightAnchor.constraint(equalToConstant: SharingCardRowViewModel.imageSize.height)
        ])
        return imageView
    }
}

// MARK: - Document image

extension SharingCardRowViewModel {

    static func documentImage() -> UIImage {
        let borderWidth: CGFloat = 1.16667
        let cornerRadius: CGFloat = 3.58333
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            let cg = context.cgContext

            let cardRect = CGRect(origin: .zero, size: imageSize)
                .insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)

            cg.saveGState()
            cardPath.addClip()
            let colours = [
                UIColor(red: 1.0, green: 0xD7 / 255, blue: 0xF3 / 255, alpha: 1).cgColor,
                UIColor(red: 1.0, green: 0xF2 / 255, blue: 0xFB / 255, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colours,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 1.66667, y: 1.66667),
                    end: CGPoint(x: 68.3333, y: 48.3333),
                    options: []
                )
            }
            cg.restoreGState()

            // Grey border.
            UIColor(red: 0x50 / 255, green: 0x5A / 255, blue: 0x5F / 255, alpha: 1).setStroke()
            cardPath.lineWidth = borderWidth
            cardPath.stroke()

            // Short dark bar near the top-left (black at 25% opacity).
            let barPath = UIBezierPath(
                roundedRect: CGRect(x: 6, y: 6, width: 32, height: 3),
                cornerRadius: 1.5
            )
            UIColor(white: 0, alpha: 0.25).setFill()
            barPath.fill()
        }
    }
}
