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

    private func makeViewModel(qrPayload: String? = "mdoc-payload", qrCodeView: QRCodeView) -> QRCodeViewModel {
        QRCodeViewModel(
            presentation: EngagementPresentation(
                qrPayload: qrPayload,
                cancelRequiresConfirmation: false
            ),
            orchestrator: mockOrchestrator,
            qrCodeView: qrCodeView,
            onCancel: {}
        )
    }

    private func makeSUT(qrPayload: String? = "mdoc-payload") throws -> QRCodeLandscapeView {
        // The landscape layout has its own QR view, separate from the portrait one.
        let image = try qrPayload.map { try QRGenerator.generateQRCode(from: $0) }
        let landscapeQRView = QRCodeView(image: image)
        let portraitQRView = QRCodeView(image: image)
        let viewModel = makeViewModel(qrPayload: qrPayload, qrCodeView: portraitQRView)
        let sut = QRCodeLandscapeView(viewModel: viewModel, qrCodeView: landscapeQRView)
        // Give the view a landscape frame and force a layout pass so constraints resolve.
        sut.frame = CGRect(x: 0, y: 0, width: 800, height: 400)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()
        return sut
    }

    // MARK: - Two-column structure

    @Test("Renders exactly two columns: a scrollable text column and a QR column")
    func rendersTwoColumns() throws {
        let sut = try makeSUT()

        let textColumn = try #require(sut.findView(with: "qr-code-landscape-text-scroll-view"))
        let qrColumn = try #require(sut.findView(with: "qr-code-landscape-qr-column"))

        #expect(textColumn is UIScrollView)
        // The two columns sit side by side: the QR column starts at the text column's trailing edge.
        #expect(qrColumn.frame.minX >= textColumn.frame.maxX - 1)
    }

    @Test("Text column contains the title and body content from the view model")
    func textColumnContainsTitleAndBody() throws {
        let sut = try makeSUT()

        let textColumn = try #require(sut.findView(with: "qr-code-landscape-text-scroll-view"))
        #expect(textColumn.findView(with: "qr-code-title") != nil)
        #expect(textColumn.findView(with: "qr-code-body") != nil)
    }

    // MARK: - Column 1 scroll behaviour

    @Test("Text column is scrollable and only scrolls vertically")
    func textColumnScrollsVerticallyOnly() throws {
        let sut = try makeSUT()

        let scrollView = try #require(
            sut.findView(with: "qr-code-landscape-text-scroll-view") as? UIScrollView
        )

        // Content width is pinned to the scroll view's frame width, so horizontal
        // scrolling is impossible — only vertical overflow can scroll.
        #expect(scrollView.contentSize.width <= scrollView.bounds.width + 1)
    }

    // MARK: - Column 2 QR sizing

    @Test("QR view is rendered at a fixed 250×250 size")
    func qrViewIsFixedSize() throws {
        let sut = try makeSUT()

        let qrColumn = try #require(sut.findView(with: "qr-code-landscape-qr-column"))
        let qrSlot = try #require(qrColumn.findView(with: "qr-code-slot"))

        // The column pins the QR view (not the inner image) to the fixed landscape size.
        #expect(qrSlot.frame.width == QRCodeViewModel.landscapeQRDimension)
        #expect(qrSlot.frame.height == QRCodeViewModel.landscapeQRDimension)
    }

    @Test("QR column is not embedded in a scroll view")
    func qrColumnIsNotScrollable() throws {
        let sut = try makeSUT()

        let qrColumn = try #require(sut.findView(with: "qr-code-landscape-qr-column"))
        #expect(sequence(first: qrColumn, next: \.superview).allSatisfy { !($0 is UIScrollView) })
    }

    @Test("When the QR payload is nil the QR image is hidden in the landscape QR column")
    func nilPayloadHidesQRImage() throws {
        let sut = try makeSUT(qrPayload: nil)

        let qrImage = try #require(sut.findView(with: QRCodeViewModel.qrImageAccessibilityIdentifier))
        #expect(qrImage.isHidden)
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
