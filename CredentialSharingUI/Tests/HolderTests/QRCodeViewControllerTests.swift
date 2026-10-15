import SharingBluetoothTransport
import Testing
import UIKit

@testable import CredentialSharingUI
@testable import SharingOrchestration

@MainActor
@Suite("QRCodeViewController Tests")
struct QRCodeViewControllerTests {

    class MockQRCodeViewControllerDelegate: QRCodeViewControllerDelegate {
        var didTapCancelCalled = false
        var didTapSettingsCalled = false
        var didFailToGenerateQRCodeCalled = false

        func didTapCancel() {
            didTapCancelCalled = true
        }

        func didTapNavigateToSettings() {
            didTapSettingsCalled = true
        }

        func didFailToGenerateQRCode() {
            didFailToGenerateQRCodeCalled = true
        }
    }

    class TestableQRCodeViewController: QRCodeViewController {
        var forcedIsMovingFromParent: Bool = false
        var viewControllerWasDismissed: Bool = false

        override var isMovingFromParent: Bool {
            return forcedIsMovingFromParent
        }
        
        override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
            viewControllerWasDismissed = true
        }
    }
    
    let engagementPresentation = EngagementPresentation(qrPayload: "test", cancelRequiresConfirmation: nil)

    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() {
        let sut = QRCodeViewController(engagementPresentation: engagementPresentation)
        sut.viewDidLoad()

        #expect(sut.view.subviews.count == 1)
        #expect(sut.activityIndicator.isAnimating)
    }

    @Test("Displays QR code view")
    func displaysQRCodeView() throws {
        let sut = QRCodeViewController(engagementPresentation: engagementPresentation)
        sut.viewDidLoad()
        sut.showQRCode()
        #expect(sut.activityIndicator.isHidden)
        #expect(sut.view.subviews.count == 2)
        #expect(sut.view.subviews.contains(where: { $0 == sut.qrCodeImageView }))
    }

    @Test("QR code width is constrained to 75% of safe area width")
    func qrCodeWidthConstraint() throws {
        let sut = try makeSUTWithQRCode()

        let hasConstraint = sut.view.constraints.contains {
            $0.firstItem === sut.qrCodeImageView &&
            $0.firstAttribute == .width &&
            $0.relation == .lessThanOrEqual &&
            $0.multiplier == 0.75
        }

        #expect(hasConstraint)
    }

    @Test("QR code height is constrained to 75% of safe area height")
    func qrCodeHeightConstraint() throws {
        let sut = try makeSUTWithQRCode()

        let hasConstraint = sut.view.constraints.contains {
            $0.firstItem === sut.qrCodeImageView &&
            $0.firstAttribute == .height &&
            $0.relation == .lessThanOrEqual &&
            $0.multiplier == 0.75
        }

        #expect(hasConstraint)
    }

    @Test("QR code maintains 1:1 aspect ratio")
    func qrCodeAspectRatio() throws {
        let sut = try makeSUTWithQRCode()

        let hasConstraint = sut.qrCodeImageView.constraints.contains {
            $0.firstAttribute == .width &&
            $0.secondAttribute == .height &&
            $0.multiplier == 1.0
        }

        #expect(hasConstraint)
    }

    @Test("Displays Settings Button")
    func displaysSettingsButton() throws {
        let sut = try makeSUTWithQRCode()
        sut.viewDidLoad()
        sut.showSettingsButton()
        #expect(sut.view.subviews.count == 2)
        #expect(
            sut.view.subviews.contains(where: {
                $0 is UIButton && ($0 as? UIButton)?.titleLabel?.text == "Go to settings"
            })
        )
    }

    @Test("presentationControllerDidDismiss: triggers cancel when dismissing (swiping down) sheet")
    func sheetDismissTriggersCancel() throws {
        let mockDelegate = MockQRCodeViewControllerDelegate()
        let sut = try makeSUTWithQRCode()
        sut.delegate = mockDelegate

        sut.showQRCode()
        sut.presentationControllerDidDismiss(try #require(sut.presentationController))

        #expect(mockDelegate.didTapCancelCalled == true, "Delegate is notified of sheet dismiss")
    }

    @Test("parent forwards cancel to the orchestrator")
    func parentHandlesCancel() {
        let mockOrchestrator = MockHolderOrchestrator()
        let container = HolderContainer(orchestrator: mockOrchestrator)

        container.didTapCancel()

        #expect(
            mockOrchestrator.cancelPresentationCalled == true,
            "Container should forward cancel to the orchestrator"
        )
    }

    // MARK: - Helpers

    private func makeSUTWithQRCode() throws -> QRCodeViewController {
        let sut = QRCodeViewController(engagementPresentation: engagementPresentation)
        sut.viewDidLoad()
        sut.showQRCode()
        return sut
    }
}
