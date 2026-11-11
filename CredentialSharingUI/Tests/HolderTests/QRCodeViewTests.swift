import CredentialSharingTestFixtures
@testable import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("QRCodeView Tests")
struct QRCodeViewTests {
    private let mockOrchestrator = MockHolderOrchestrator()

    private func qrImageView(in view: QRCodeView) -> UIImageView? {
        view.findView(with: QRCodeViewModel.qrImageAccessibilityIdentifier) as? UIImageView
    }

    @Test("A non-nil initial payload shows the QR image")
    func initialPayloadShowsImage() throws {
        let sut = QRCodeView(orchestrator: mockOrchestrator, initialPayload: "mdoc-payload")

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isHidden == false)
        #expect(imageView.image != nil)
    }

    @Test("A nil initial payload shows blank space (no visible QR image)")
    func nilInitialPayloadIsBlank() throws {
        let sut = QRCodeView(orchestrator: mockOrchestrator, initialPayload: nil)

        let imageView = try #require(qrImageView(in: sut))
        #expect(imageView.isHidden)
        #expect(imageView.image == nil)
    }

    @Test("Refreshing nil → payload shows the QR, then payload → nil blanks it again")
    func updateTogglesBetweenStates() throws {
        let sut = QRCodeView(orchestrator: mockOrchestrator, initialPayload: nil)
        let imageView = try #require(qrImageView(in: sut))

        // nil → payload: QR appears
        sut.update(payload: "first-payload")
        #expect(imageView.isHidden == false)
        let firstImage = try #require(imageView.image)

        // payload → new payload: QR replaced in place
        sut.update(payload: "second-payload")
        #expect(imageView.isHidden == false)
        #expect(imageView.image != nil)

        // payload → nil (hide/grace window): QR blanked
        sut.update(payload: nil)
        #expect(imageView.isHidden)
        #expect(imageView.image == nil)

        // The same image view instance is reused throughout.
        #expect(qrImageView(in: sut) === imageView)
        _ = firstImage
    }

    @Test("The QR image carries the alt text and image trait for VoiceOver")
    func qrImageAccessibility() throws {
        let sut = QRCodeView(orchestrator: mockOrchestrator, initialPayload: "mdoc-payload")

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
