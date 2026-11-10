import CredentialSharingTestFixtures
import DesignSystem
@testable import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("QRCodeLandscapeView Tests")
struct QRCodeLandscapeViewTests {
    private let mockOrchestrator = MockHolderOrchestrator()

    private func makeViewModel(qrPayload: String? = "mdoc-payload") -> QRCodeViewModel {
        QRCodeViewModel(
            presentation: EngagementPresentation(
                qrPayload: qrPayload,
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            onCancel: {}
        )
    }

    private func makeSUT(qrPayload: String? = "mdoc-payload") -> QRCodeLandscapeView {
        let sut = QRCodeLandscapeView(viewModel: makeViewModel(qrPayload: qrPayload))
        // Give the view a landscape frame and force a layout pass so constraints resolve.
        sut.frame = CGRect(x: 0, y: 0, width: 800, height: 400)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()
        return sut
    }

    // MARK: - Two-column structure

    @Test("Renders exactly two columns: a scrollable text column and a QR column")
    func rendersTwoColumns() throws {
        let sut = makeSUT()

        let textColumn = try #require(sut.findView(with: "qr-code-landscape-text-scroll-view"))
        let qrColumn = try #require(sut.findView(with: "qr-code-landscape-qr-column"))

        #expect(textColumn is UIScrollView)
        // The two columns sit side by side: the QR column starts at the text column's trailing edge.
        #expect(qrColumn.frame.minX >= textColumn.frame.maxX - 1)
    }

    @Test("Text column contains the title and body content from the view model")
    func textColumnContainsTitleAndBody() throws {
        let sut = makeSUT()

        let textColumn = try #require(sut.findView(with: "qr-code-landscape-text-scroll-view"))
        #expect(textColumn.findView(with: "qr-code-title") != nil)
        #expect(textColumn.findView(with: "qr-code-body") != nil)
    }

    // MARK: - Column 1 scroll behaviour

    @Test("Text column is scrollable and only scrolls vertically")
    func textColumnScrollsVerticallyOnly() throws {
        let sut = makeSUT()

        let scrollView = try #require(
            sut.findView(with: "qr-code-landscape-text-scroll-view") as? UIScrollView
        )

        // Content width is pinned to the scroll view's frame width, so horizontal
        // scrolling is impossible — only vertical overflow can scroll.
        #expect(scrollView.contentSize.width <= scrollView.bounds.width + 1)
    }

    // MARK: - Column 2 QR sizing

    @Test("QR code is rendered at a fixed 250×250 size")
    func qrCodeIsFixedSize() throws {
        let sut = makeSUT()

        let qrColumn = try #require(sut.findView(with: "qr-code-landscape-qr-column"))
        let qrImage = try #require(qrColumn.findView(with: QRCodeViewModel.qrImageAccessibilityIdentifier))

        // The fixed-size constraints are constant-based (== 250). The image view also
        // carries an intrinsic aspect-ratio constraint (height == width * ratio, constant 0),
        // so match on the constant rather than just the attribute.
        let fixedWidth = qrImage.constraints.contains {
            $0.firstAttribute == .width
                && $0.relation == .equal
                && $0.constant == QRCodeViewModel.landscapeQRDimension
        }
        let fixedHeight = qrImage.constraints.contains {
            $0.firstAttribute == .height
                && $0.relation == .equal
                && $0.constant == QRCodeViewModel.landscapeQRDimension
        }

        #expect(fixedWidth)
        #expect(fixedHeight)
        // The rendered frame is square at the fixed dimension.
        #expect(qrImage.frame.width == QRCodeViewModel.landscapeQRDimension)
        #expect(qrImage.frame.height == QRCodeViewModel.landscapeQRDimension)
    }

    @Test("QR column is not embedded in a scroll view")
    func qrColumnIsNotScrollable() throws {
        let sut = makeSUT()

        let qrColumn = try #require(sut.findView(with: "qr-code-landscape-qr-column"))
        #expect(sequence(first: qrColumn, next: \.superview).allSatisfy { !($0 is UIScrollView) })
    }

    @Test("When the QR payload is nil no QR image is rendered in the landscape QR column")
    func nilPayloadRendersNoQRImage() throws {
        let sut = makeSUT(qrPayload: nil)

        #expect(sut.findView(with: QRCodeViewModel.qrImageAccessibilityIdentifier) == nil)
        // The QR column still exists to reserve the second-column space.
        #expect(sut.findView(with: "qr-code-landscape-qr-column") != nil)
    }
}

// MARK: - Test helpers

private extension UIView {
    func findView(with accessibilityIdentifier: String) -> UIView? {
        if self.accessibilityIdentifier == accessibilityIdentifier {
            return self
        }
        for subview in subviews {
            if let found = subview.findView(with: accessibilityIdentifier) {
                return found
            }
        }
        return nil
    }
}
