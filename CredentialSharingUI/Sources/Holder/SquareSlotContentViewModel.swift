import DesignSystem
import UIKit

/// Wraps a content view model in a container that fills the available width and is
/// constrained to a 1:1 aspect ratio (height == width), centring the wrapped content.
///
/// Used by the QR code screen's empty state so the blank placeholder occupies the same
/// square footprint that the (natural, width-driven, square) QR image would. The QR image
/// keeps its natural size; this matches the *empty* slot to it so the body copy below does
/// not shift when the screen swaps between the QR image and the blank placeholder.
@MainActor
struct SquareSlotContentViewModel: ContentViewModel {
    typealias ViewType = SquareSlotContentView

    let wrapped: any ContentViewModel

    let accessibilityIdentifier: String?
    let accessibilityTraits: UIAccessibilityTraits?
    let verticalPadding: VerticalPadding?
    let horizontalPadding: HorizontalPadding?

    init(
        wrapping wrapped: any ContentViewModel,
        accessibilityIdentifier: String? = nil,
        verticalPadding: VerticalPadding? = .vertical(DesignSystem.Spacing.default),
        horizontalPadding: HorizontalPadding? = .horizontal(DesignSystem.Spacing.default)
    ) {
        self.wrapped = wrapped
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityTraits = nil
        self.verticalPadding = verticalPadding
        self.horizontalPadding = horizontalPadding
    }
}

@MainActor
final class SquareSlotContentView: UIView, ContentView {
    init(viewModel: SquareSlotContentViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        if let identifier = viewModel.accessibilityIdentifier {
            accessibilityIdentifier = identifier
        }

        let content = viewModel.wrapped.createUIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        // Square footprint: height tracks width, matching how the aspect-fit QR image
        // (a square image) sizes itself when it fills the same content width.
        let aspect = heightAnchor.constraint(equalTo: widthAnchor)
        // Lower the priority so the stack view can still lay the slot out during
        // transient / zero-width layout passes without constraint conflicts.
        aspect.priority = .required - 1

        NSLayoutConstraint.activate([
            aspect,
            // Centre the wrapped content within the square, keeping it inside the bounds.
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            content.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// An empty content view model that renders blank space. Used as the filler inside a
/// ``SquareSlotContentViewModel`` for the QR code screen's "no QR yet" state.
@MainActor
struct BlankContentViewModel: ContentViewModel {
    typealias ViewType = BlankContentView

    let accessibilityIdentifier: String?
    let accessibilityTraits: UIAccessibilityTraits?
    let verticalPadding: VerticalPadding?
    let horizontalPadding: HorizontalPadding?

    init(accessibilityIdentifier: String? = nil) {
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityTraits = nil
        self.verticalPadding = nil
        self.horizontalPadding = nil
    }
}

@MainActor
final class BlankContentView: UIView, ContentView {
    init(viewModel: BlankContentViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        if let identifier = viewModel.accessibilityIdentifier {
            accessibilityIdentifier = identifier
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
