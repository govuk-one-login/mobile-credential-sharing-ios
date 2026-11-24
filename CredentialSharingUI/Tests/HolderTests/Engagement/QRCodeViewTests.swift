import DesignSystem
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

    // MARK: - White box / border

    @Test("The QR image fills the white box, inset only by the border width")
    func qrIsInsetByBorderWidth() throws {
        let sut = QRCodeView(image: try makeImage())
        sut.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        let whiteBox = try #require(sut.findView(with: "qr-code-white-box"))
        #expect(whiteBox.backgroundColor == .white)
        #expect(whiteBox.frame == sut.bounds)

        // The 4-module quiet zone is part of the image itself (see QRGeneratorTests), so the
        // only inset is the border width.
        let imageView = try #require(qrImageView(in: sut))
        let inset = QRCodeView.borderWidth
        #expect(imageView.frame.minX == inset)
        #expect(imageView.frame.minY == inset)
        #expect(imageView.frame.maxX == whiteBox.bounds.width - inset)
        #expect(imageView.frame.maxY == whiteBox.bounds.height - inset)
    }

    @Test("The white box is rounded and clips the image so its square corners cannot stick out")
    func whiteBoxClipsImageToRoundedCorners() throws {
        let sut = QRCodeView(image: try makeImage())

        let whiteBox = try #require(sut.findView(with: "qr-code-white-box"))
        #expect(whiteBox.layer.cornerRadius == 8)
        #expect(whiteBox.layer.masksToBounds)
    }

    @Test("A 1pt border with 8pt corner radius is drawn above the image")
    func borderIsOverlaidAboveImage() throws {
        let sut = QRCodeView(image: try makeImage())
        sut.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        sut.setNeedsLayout()
        sut.layoutIfNeeded()

        let whiteBox = try #require(sut.findView(with: "qr-code-white-box"))
        let border = try #require(sut.findView(with: "qr-code-border"))
        let imageView = try #require(qrImageView(in: sut))

        #expect(QRCodeView.borderWidth == 1)
        #expect(border.layer.borderWidth == 1)
        #expect(border.layer.cornerRadius == 8)
        #expect(border.frame == whiteBox.bounds)
        #expect(border.isUserInteractionEnabled == false)

        // The border is the last subview, so it draws above the image.
        let borderIndex = try #require(whiteBox.subviews.firstIndex(of: border))
        let imageIndex = try #require(whiteBox.subviews.firstIndex(of: imageView))
        #expect(borderIndex > imageIndex)
    }

    @Test("The border colour is Grey 8 in light mode and white in dark mode")
    func borderColourPerAppearance() {
        let light = QRCodeView.borderColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = QRCodeView.borderColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        #expect(light == DesignSystem.Color.Base.grey8)
        #expect(dark == DesignSystem.Color.Base.white)
    }

    @Test("The border colour follows light and dark mode changes")
    func borderColourFollowsAppearance() throws {
        let sut = QRCodeView(image: try makeImage())
        let window = UIWindow()
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(sut)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let border = try #require(sut.findView(with: "qr-code-border"))

        window.overrideUserInterfaceStyle = .light
        window.layoutIfNeeded()
        #expect(border.layer.borderColor == DesignSystem.Color.Base.grey8.cgColor)

        window.overrideUserInterfaceStyle = .dark
        window.layoutIfNeeded()
        #expect(border.layer.borderColor == DesignSystem.Color.Base.white.cgColor)
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
