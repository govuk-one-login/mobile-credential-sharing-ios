import DesignSystem
import UIKit

// MARK: - AttributesCardRowViewModel

/// A single row of the "Agree to Share" card.
@MainActor
struct AttributesCardRowViewModel: ContentViewModel {
    typealias ViewType = AttributesCardRowView

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
        self.verticalPadding = .vertical(0)
        self.horizontalPadding = .horizontal(0)
    }
}

// MARK: - AttributesCardRowView

@MainActor
final class AttributesCardRowView: UIView, ContentView {
    private static let standardInset = DesignSystem.Spacing.default

    private let stack = UIStackView()

    override var accessibilityFrame: CGRect {
        get { UIAccessibility.convertToScreenCoordinates(bounds, in: self) }
        set { super.accessibilityFrame = newValue }
    }

    init(viewModel: AttributesCardRowViewModel) {
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

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = Self.standardInset
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Self.standardInset,
            leading: Self.standardInset,
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

        updateStackAxis()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.preferredContentSizeCategory != previous?.preferredContentSizeCategory {
            updateStackAxis()
        }
    }

    /// Once the text size exceeds XXL (i.e. any accessibility size) a header row
    /// with a leading image stacks vertically (image on top, text below) to
    /// match the design; otherwise it lays out side by side. Rows without an
    /// image have a single arranged subview and always stay horizontal. This was
    /// explicitly requested in design review.
    private func updateStackAxis() {
        let hasLeadingImage = stack.arrangedSubviews.count > 1
        let isVertical = hasLeadingImage && traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        stack.axis = isVertical ? .vertical : .horizontal
        stack.alignment = isVertical ? .leading : .top
    }

    private func makeLabel(for title: GDSLocalisedString) -> UIView {
        let view = GDSTextViewModel(
            title: title,
            titleFont: DesignSystem.Font.Base.body,
            textColor: DesignSystem.Color.Text.primary,
            verticalPadding: .vertical(0),
            horizontalPadding: .horizontal(0)
        ).createUIView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    private func makeImageView(_ image: UIImage) -> UIView {
        let view = GDSImageViewModel(
            image: image,
            contentMode: .scaleAspectFit,
            imageFixedHeight: AttributesCardRowViewModel.imageSize.height,
            verticalPadding: .vertical(0),
            horizontalPadding: .horizontal(0)
        ).createUIView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.widthAnchor
            .constraint(equalToConstant: AttributesCardRowViewModel.imageSize.width)
            .isActive = true
        return view
    }
}
