import DesignSystem
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("Attributes Card Row Tests")
struct AttributesCardRowTests {

    // MARK: - Helpers

    private func makeViewModel(
        title: GDSLocalisedString = "A title",
        isGrey: Bool = false,
        leadingImage: UIImage? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityTraits: UIAccessibilityTraits? = nil
    ) -> AttributesCardRowViewModel {
        AttributesCardRowViewModel(
            title: title,
            isGrey: isGrey,
            leadingImage: leadingImage,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityTraits: accessibilityTraits
        )
    }

    // MARK: - View model

    @Test("Image size matches the fixed design size")
    func imageSize() {
        #expect(AttributesCardRowViewModel.imageSize == CGSize(width: 70, height: 50))
    }

    @Test("Initialiser stores the supplied values")
    func initStoresValues() {
        let image = UIImage()
        let viewModel = makeViewModel(
            title: "Hello",
            isGrey: true,
            leadingImage: image,
            accessibilityIdentifier: "row-id",
            accessibilityTraits: .header
        )

        #expect(viewModel.title.value == "Hello")
        #expect(viewModel.isGrey == true)
        #expect(viewModel.leadingImage === image)
        #expect(viewModel.accessibilityIdentifier == "row-id")
        #expect(viewModel.accessibilityTraits == .header)
    }

    @Test("Initialiser applies zero padding so the view owns all insets")
    func initZeroesPadding() {
        let viewModel = makeViewModel()

        guard case .vertical(let vertical)? = viewModel.verticalPadding else {
            Issue.record("vertical padding is not symmetric .vertical")
            return
        }
        guard case .horizontal(let horizontal)? = viewModel.horizontalPadding else {
            Issue.record("horizontal padding is not symmetric .horizontal")
            return
        }
        #expect(vertical == 0)
        #expect(horizontal == 0)
    }

    @Test("Optional parameters default to nil")
    func initDefaults() {
        let viewModel = AttributesCardRowViewModel(title: "Title", isGrey: false)
        #expect(viewModel.leadingImage == nil)
        #expect(viewModel.accessibilityIdentifier == nil)
        #expect(viewModel.accessibilityTraits == nil)
    }

    // MARK: - View: accessibility

    @Test("View is a single accessibility element carrying the title and identifier")
    func viewAccessibility() {
        let viewModel = makeViewModel(
            title: "Share this",
            accessibilityIdentifier: "the-id"
        )
        let view = AttributesCardRowView(viewModel: viewModel)

        #expect(view.isAccessibilityElement == true)
        #expect(view.accessibilityLabel == "Share this")
        #expect(view.accessibilityIdentifier == "the-id")
    }

    @Test("Accessibility traits are applied when supplied")
    func viewAccessibilityTraits() {
        let viewModel = makeViewModel(accessibilityTraits: .header)
        let view = AttributesCardRowView(viewModel: viewModel)
        #expect(view.accessibilityTraits.contains(.header))
    }

    // MARK: - View: background

    @Test("Grey rows receive a background colour")
    func greyRowHasBackground() {
        let view = AttributesCardRowView(viewModel: makeViewModel(isGrey: true))
        #expect(view.backgroundColor != nil)
    }

    @Test("Non-grey rows have no background colour")
    func nonGreyRowHasNoBackground() {
        let view = AttributesCardRowView(viewModel: makeViewModel(isGrey: false))
        #expect(view.backgroundColor == nil)
    }

    // MARK: - View: layout content

    @Test("View without an image contains only a label")
    func viewWithoutImage() {
        let view = AttributesCardRowView(viewModel: makeViewModel())
        #expect(imageViews(in: view).isEmpty)
        #expect(!labels(in: view).isEmpty)
    }

    @Test("View with an image contains both an image view and a label")
    func viewWithImage() {
        let view = AttributesCardRowView(viewModel: makeViewModel(leadingImage: UIImage()))
        #expect(!imageViews(in: view).isEmpty)
        #expect(!labels(in: view).isEmpty)
    }

    @Test("Plain-string title renders as the label text")
    func plainStringTitle() {
        let view = AttributesCardRowView(viewModel: makeViewModel(title: "Plain title"))
        let label = labels(in: view).first
        #expect(label?.text == "Plain title")
    }

    @Test("Image view uses the fixed design size")
    func imageViewSized() {
        let view = AttributesCardRowView(viewModel: makeViewModel(leadingImage: UIImage()))
        view.layoutIfNeeded()
        guard let imageView = imageViews(in: view).first else {
            Issue.record("no image view present")
            return
        }
        let widthConstraint = imageView.constraints.first { $0.firstAttribute == .width }
        let heightConstraint = imageView.constraints.first { $0.firstAttribute == .height }
        #expect(widthConstraint?.constant == AttributesCardRowViewModel.imageSize.width)
        #expect(heightConstraint?.constant == AttributesCardRowViewModel.imageSize.height)
    }

    // MARK: - Subview helpers

    private func allSubviews(in view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { allSubviews(in: $0) }
    }

    private func labels(in view: UIView) -> [UILabel] {
        allSubviews(in: view).compactMap { $0 as? UILabel }
    }

    private func imageViews(in view: UIView) -> [UIImageView] {
        allSubviews(in: view).compactMap { $0 as? UIImageView }
    }
}
