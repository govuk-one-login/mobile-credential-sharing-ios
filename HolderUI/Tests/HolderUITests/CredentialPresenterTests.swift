import ISOModels
import Testing
import UIKit

@testable import HolderUI

@MainActor
@Suite("CredentialPresenter Tests")
struct CredentialPresenterTests {
    var sut: CredentialPresenter
    init() {
        sut = CredentialPresenter()
    }

    @Test("Present credential func initialises QRCodeViewController")
    func presentCredentialInitialisesQRVC() {
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        #expect(sut.qrCodeViewController == nil)
        sut.presentCredential(Data(), over: vc)

        #expect(sut.qrCodeViewController != nil)
        #expect(sut.qrCodeViewController?.delegate === sut)
    }

    @Test("Did tap navigate to settings func preserves initial PeripheralSession")
    func didTapNavigateToSettingsReInitsPeripheralSession() throws {
        let initialPeripheralSession = sut.peripheralSession
        sut.didTapNavigateToSettings()

        #expect(sut.peripheralSession == initialPeripheralSession)
    }

    @Test(
        "peripheralSessionDidUpdateState func passes showQRCode when no error"
    )
    func passesShowQRCodeWhenNoError() throws {
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        sut.peripheralSessionDidUpdateState(withError: nil)
        let qrCodeViewController = try #require(sut.qrCodeViewController)
        #expect(
            qrCodeViewController.view.subviews
                .contains(where: { $0 == qrCodeViewController.qrCodeImageView })
        )
    }

    @Test("peripheralSessionDidUpdateState func passes showSettingsButton when given state error")
    func passesShowSettingsButtonWhenPassedError() throws {
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        sut.peripheralSessionDidUpdateState(withError: .notPoweredOn(.poweredOff))
        let qrCodeViewController = try #require(sut.qrCodeViewController)
        #expect(
            qrCodeViewController.view.subviews.contains(where: {
                $0 is UIButton && ($0 as? UIButton)?.titleLabel?.text == "Go to settings"
            })
        )
    }

    @Test(
        "peripheralSessionDidUpdateState func navigates to error view when given permissions error"
    )
    func navigatesToErrorViewWhenPassedPermissionsError() throws {
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        let mockQRCodeViewController = QRCodeViewControllerTests.TestableQRCodeViewController()
        sut.qrCodeViewController = mockQRCodeViewController
        sut.peripheralSessionDidUpdateState(withError: .permissionsNotGranted(.denied))

        let navigationController = try #require(sut.navigationController)
        let errorViewController = try #require(navigationController.viewControllers.first(where: { (type(of: $0) == ErrorViewController.self) }))
        
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        #expect(
            errorViewController.view.subviews.contains(where: {
                $0 is UILabel && ($0 as? UILabel)?.text == "Permission permanently denied"
            })
        )
        #expect(mockQRCodeViewController.viewControllerWasDismissed)
    }
    
    @Test(
        "peripheralSessionDidUpdateState func navigates to error view when given connection error"
    )
    func navigatesToErrorViewWhenPassedConnectionError() throws {
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        let mockQRCodeViewController = QRCodeViewControllerTests.TestableQRCodeViewController()
        sut.qrCodeViewController = mockQRCodeViewController
        sut.peripheralSessionDidUpdateState(withError: .connectionTerminated)

        let navigationController = try #require(sut.navigationController)
        let errorViewController = try #require(navigationController.viewControllers.first(where: { (type(of: $0) == ErrorViewController.self) }))
        
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        #expect(
            errorViewController.view.subviews.contains(where: {
                $0 is UILabel && ($0 as? UILabel)?.text == "Bluetooth disconnected unexpectedly."
            })
        )
        #expect(mockQRCodeViewController.viewControllerWasDismissed)
    }
}

class EmptyViewController: UIViewController {}
