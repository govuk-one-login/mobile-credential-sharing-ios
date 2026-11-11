import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("QRCodeView Tests")
struct QRCodeViewTests {
    private func qrImageView(in view: QRCodeView) -> UIImageView? {
        view.findView(with: QRCodeViewModel.qrImageAccessibilityIdentifier) as? UIImageView
    }

    @Test("A non-nil initial payload shows the QR image")
    func initialPayloadShowsImage() throws {
        let sut = try QRCodeView(initialPayload: "mdoc-payload")

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isHidden == false)
        #expect(imageView.image != nil)
    }

    @Test("A nil initial payload shows blank space (no visible QR image)")
    func nilInitialPayloadIsBlank() throws {
        let sut = try QRCodeView(initialPayload: nil)

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isHidden)
        #expect(imageView.image == nil)
    }

    @Test("Refreshing nil → payload shows the QR, then payload → nil blanks it again")
    func updateTogglesBetweenStates() throws {
        let sut = try QRCodeView(initialPayload: nil)
        let imageView = try #require(qrImageView(in: sut))

        // nil → payload: QR appears
        try sut.update(payload: "first-payload")
        #expect(imageView.isHidden == false)
        #expect(imageView.image != nil)

        // payload → new payload: QR replaced in place
        try sut.update(payload: "second-payload")
        #expect(imageView.isHidden == false)
        #expect(imageView.image != nil)

        // payload → nil (hide/grace window): QR blanked
        try sut.update(payload: nil)
        #expect(imageView.isHidden)
        #expect(imageView.image == nil)

        // The same image view instance is reused throughout.
        #expect(qrImageView(in: sut) === imageView)
    }

    @Test("A nil payload never throws (valid hidden state)")
    func nilPayloadDoesNotThrow() throws {
        let sut = try QRCodeView(initialPayload: "mdoc-payload")
        // Should not throw — blanking for the hide/grace window is a valid state.
        try sut.update(payload: nil)
        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isHidden)
    }

    @Test("The QR image carries the alt text and image trait for VoiceOver")
    func qrImageAccessibility() throws {
        let sut = try QRCodeView(initialPayload: "mdoc-payload")

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isAccessibilityElement)
        #expect(imageView.accessibilityTraits.contains(.image))
        #expect(imageView.accessibilityLabel?.isEmpty == false)
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
