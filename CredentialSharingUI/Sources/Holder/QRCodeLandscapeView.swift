import DesignSystem
import UIKit

/// The two-column landscape layout for the QR code screen, per the ticket's landscape
/// requirements:
/// - Column 1: title and body copy. Scrollable when the text does not fit.
/// - Column 2: the QR code at a fixed 250×250 size. Not scrollable.
///
/// Content is sourced from `QRCodeViewModel` so portrait and landscape render the exact
/// same copy and QR image. `EngagementViewController` owns an instance and shows/hides it
/// based on orientation.
@MainActor
final class QRCodeLandscapeView: UIView {
    private let viewModel: QRCodeViewModel

    init(viewModel: QRCodeViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = viewModel.backgroundColor
        setUpColumns()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpColumns() {
        let textColumn = makeTextColumn()
        let qrColumn = makeQRColumn()

        addSubview(textColumn)
        addSubview(qrColumn)

        NSLayoutConstraint.activate([
            // Column 1: title + body copy. Takes the leading portion and may scroll.
            textColumn.leadingAnchor.constraint(equalTo: leadingAnchor),
            textColumn.topAnchor.constraint(equalTo: topAnchor),
            textColumn.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Column 2: QR code, fixed size, not scrollable, trailing side.
            qrColumn.leadingAnchor.constraint(equalTo: textColumn.trailingAnchor),
            qrColumn.trailingAnchor.constraint(equalTo: trailingAnchor),
            qrColumn.topAnchor.constraint(equalTo: topAnchor),
            qrColumn.bottomAnchor.constraint(equalTo: bottomAnchor),

            // The QR column hugs its fixed content; the text column takes the rest.
            qrColumn.widthAnchor.constraint(
                greaterThanOrEqualToConstant:
                    QRCodeViewModel.landscapeQRDimension + DesignSystem.Spacing.default * 2
            )
        ])
    }

    /// Column 1 — scrollable title and body text.
    private func makeTextColumn() -> UIView {
        let stack = UIStackView(
            arrangedSubviews: [
                viewModel.titleContent.createUIView(),
                viewModel.bodyContent.createUIView()
            ]
        )
        stack.axis = .vertical
        stack.spacing = DesignSystem.Spacing.default
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: DesignSystem.Spacing.default,
            leading: DesignSystem.Spacing.default,
            bottom: DesignSystem.Spacing.default,
            trailing: DesignSystem.Spacing.default
        )

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.accessibilityIdentifier = "qr-code-landscape-text-scroll-view"
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // Pin the content width to the scroll view so it only scrolls vertically.
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        return scrollView
    }

    /// Column 2 — the QR code at a fixed 250×250 size, vertically centred and not scrollable.
    private func makeQRColumn() -> UIView {
        let column = UIView()
        column.translatesAutoresizingMaskIntoConstraints = false
        column.accessibilityIdentifier = "qr-code-landscape-qr-column"

        let qrView = viewModel.makeLandscapeQRContent()
            .first?
            .createUIView() ?? UIView()
        qrView.translatesAutoresizingMaskIntoConstraints = false

        column.addSubview(qrView)
        NSLayoutConstraint.activate([
            qrView.centerXAnchor.constraint(equalTo: column.centerXAnchor),
            qrView.centerYAnchor.constraint(equalTo: column.centerYAnchor),
            qrView.leadingAnchor.constraint(
                greaterThanOrEqualTo: column.leadingAnchor,
                constant: DesignSystem.Spacing.default
            ),
            qrView.trailingAnchor.constraint(
                lessThanOrEqualTo: column.trailingAnchor,
                constant: -DesignSystem.Spacing.default
            )
        ])

        // The ticket requires the QR code to be exactly 250×250 in landscape. Apply the
        // fixed sizing only to the generated QR image — the loading-indicator fallback
        // keeps its intrinsic size centred within the reserved column.
        if qrView.accessibilityIdentifier == QRCodeViewModel.qrImageAccessibilityIdentifier {
            NSLayoutConstraint.activate([
                qrView.widthAnchor.constraint(equalToConstant: QRCodeViewModel.landscapeQRDimension),
                qrView.heightAnchor.constraint(equalToConstant: QRCodeViewModel.landscapeQRDimension)
            ])
        }

        return column
    }
}
