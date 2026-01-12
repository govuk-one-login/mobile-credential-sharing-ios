import Holder
import Testing
import UIKit

@testable import HolderUI

@MainActor
@Suite("QRCodeViewController Tests")
struct QRCodeViewControllerTests {
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() {
        let sut = QRCodeViewController()
        sut.viewDidLoad()

        #expect(sut.view.subviews.count == 1)
        #expect(sut.activityIndicator.isAnimating)
    }

    @Test("Displays QR code view")
    func displaysQRCodeView() throws {
        let qrCode = try QRGenerator(data: Data()).generateQRCode()
        let sut = QRCodeViewController(qrCode: qrCode)
        sut.viewDidLoad()
        sut.showQRCode()
        #expect(sut.activityIndicator.isHidden)
        #expect(sut.view.subviews.count == 2)
        #expect(sut.view.subviews.contains(where: { $0 == sut.qrCodeImageView }))
    }

    @Test("Displays Settings Button")
    func displaysSettingsButton() {
        let sut = QRCodeViewController()
        sut.viewDidLoad()
        sut.showSettingsButton()
        #expect(sut.view.subviews.count == 2)
        #expect(
            sut.view.subviews.contains(where: {
                $0 is UIButton && ($0 as? UIButton)?.titleLabel?.text == "Go to settings"
            })
        )
    }
}
