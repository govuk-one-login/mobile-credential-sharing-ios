import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("QRCodeView Tests")
struct QRCodeViewTests {
    private func makeImage() throws -> UIImage {
        try QRGenerator.generateQRCode(from: "mdoc-payload")
    }

    private func qrImageView(in view: QRCodeView) -> UIImageView? {
        view.findView(with: EngagementViewModel.qrImageAccessibilityIdentifier) as? UIImageView
    }

    @Test("A non-nil image is shown")
    func imageIsShown() throws {
        let sut = QRCodeView(image: try makeImage())

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isHidden == false)
        #expect(imageView.image != nil)
    }

    @Test("A nil image shows blank space (no visible QR image)")
    func nilImageIsBlank() throws {
        let sut = QRCodeView(image: nil)

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isHidden)
        #expect(imageView.image == nil)
    }

    @Test("show(image:) toggles between showing the QR and blanking it")
    func showTogglesBetweenStates() throws {
        let sut = QRCodeView(image: nil)
        let imageView = try #require(qrImageView(in: sut))

        // nil → image: QR appears
        sut.show(image: try makeImage())
        #expect(imageView.isHidden == false)
        #expect(imageView.image != nil)

        // image → nil (hide/grace window): QR blanked
        sut.show(image: nil)
        #expect(imageView.isHidden)
        #expect(imageView.image == nil)

        // The same image view instance is reused throughout.
        #expect(qrImageView(in: sut) === imageView)
    }

    @Test("The QR image carries the alt text and image trait for VoiceOver")
    func qrImageAccessibility() throws {
        let sut = QRCodeView(image: try makeImage())

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isAccessibilityElement)
        #expect(imageView.accessibilityTraits.contains(.image))
        #expect(imageView.accessibilityLabel?.isEmpty == false)
    }

    // MARK: - White box / padding

    @Test("The QR sits in a white box with 16px internal padding on all sides")
    func qrHasWhiteBoxWithPadding() throws {
        let sut = QRCodeView(image: try makeImage())
        sut.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        let whiteBox = try #require(sut.findView(with: "qr-code-white-box"))
        #expect(whiteBox.backgroundColor == .white)
        #expect(whiteBox.frame == sut.bounds)

        let imageView = try #require(qrImageView(in: sut))
        let padding = QRCodeView.whitePadding
        #expect(imageView.frame.minX == padding)
        #expect(imageView.frame.minY == padding)
        #expect(imageView.frame.maxX == whiteBox.bounds.width - padding)
        #expect(imageView.frame.maxY == whiteBox.bounds.height - padding)
    }

    @Test("The white box is hidden in the blank state so no white square shows")
    func whiteBoxHiddenWhenBlank() throws {
        let sut = QRCodeView(image: nil)

        let whiteBox = try #require(sut.findView(with: "qr-code-white-box"))
        #expect(whiteBox.isHidden)

        sut.show(image: try makeImage())
        #expect(whiteBox.isHidden == false)

        sut.show(image: nil)
        #expect(whiteBox.isHidden)
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
