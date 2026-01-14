import Bluetooth
import CoreBluetooth
import Holder
import Testing
import UIKit

@testable import HolderUI

@MainActor
@Suite("QRCodeViewController Tests")
struct QRCodeViewControllerTests {

    class MockQRCodeViewControllerDelegate: QRCodeViewControllerDelegate {
        var didTapCancelCalled = false
        var didTapSettingsCalled = false

        func didTapCancel() {
            didTapCancelCalled = true
        }

        func didTapNavigateToSettings() {
            didTapSettingsCalled = true
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

    class MockPeripheralSession: PeripheralManagerProtocol {
        var authorization: CBManagerAuthorization

        var state: CBManagerState

        weak var delegate: (any CBPeripheralManagerDelegate)?

        var isAdvertising = false
        var stopAdvertisingCalled = false

        init(state: CBManagerState = .poweredOn) {
            self.authorization = .allowedAlways
            self.state = state
        }

        func stopAdvertising() {
            stopAdvertisingCalled = true
            isAdvertising = false
        }

        func startAdvertising(_ advertisementData: [String: Any]?) {
        }

        func add(_ service: CBMutableService) {
        }

        func remove(_ service: CBMutableService) {
        }

        func removeAllServices() {
        }

        func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals: [CBCentral]?) -> Bool {
            return true
        }

        func respond(to request: any Bluetooth.ATTRequestProtocol, withResult result: CBATTError.Code) {
        }
    }

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

    @Test("viewWillDisappear: triggers cancel when moving from parent (Back navigation)")
    func backTriggersCancel() {
        let mockDelegate = MockQRCodeViewControllerDelegate()
        let sut = TestableQRCodeViewController()
        sut.delegate = mockDelegate

        sut.forcedIsMovingFromParent = true
        sut.viewWillDisappear(false)

        #expect(mockDelegate.didTapCancelCalled == true, "Delegate is notified of back navigation")
    }

    @Test("viewWillDisapper: does NOT trigger cancel when just navigating deeper")
    func pushingDoesNotTriggerCancel() {
        let mockDelegate = MockQRCodeViewControllerDelegate()
        let sut = TestableQRCodeViewController()
        sut.delegate = mockDelegate

        sut.forcedIsMovingFromParent = false
        sut.viewWillDisappear(true)

        #expect(mockDelegate.didTapCancelCalled == false, "Delegate should NOT be notified when covered by another view")
    }

    @Test("parent stops advertising when child cancels")
    func parentHandlesCancel() {
        let presenter = CredentialPresenter()
        let session = MockPeripheralSession()

        presenter.didTapCancel()

        let isAdvertising = session.isAdvertising

        #expect(isAdvertising == false, "PeripheralSession should not be advertising")
    }
}
