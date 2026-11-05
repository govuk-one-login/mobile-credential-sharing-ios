import DesignSystem
import UIKit

// MARK: - SharingCardRowViewModel

/// A single row of the "Agree to Share" card.
@MainActor
struct SharingCardRowViewModel: ContentViewModel {
    typealias ViewType = SharingCardRowView

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

// MARK: - SharingCardRowView

@MainActor
final class SharingCardRowView: UIView, ContentView {
    private static let standardInset = DesignSystem.Spacing.default

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
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            imageFixedHeight: SharingCardRowViewModel.imageSize.height,
            verticalPadding: .vertical(0),
            horizontalPadding: .horizontal(0)
        ).createUIView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.widthAnchor
            .constraint(equalToConstant: SharingCardRowViewModel.imageSize.width)
            .isActive = true
        return view
    }
}
