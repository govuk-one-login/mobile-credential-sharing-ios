@testable import HolderUI
import ISOModels
import Testing
import UIKit

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
        let _ = UINavigationController(
            rootViewController: vc
        )
        #expect(sut.qrCodeViewController == nil)
        sut.presentCredential(Data(), over: vc)
        
        #expect(sut.qrCodeViewController != nil)
        #expect(sut.qrCodeViewController?.delegate === sut)
    }
    
    @Test("Did tap navigate to settings func re-inits PeripheralSession")
    func didTapNavigateToSettingsReInitsPeripheralSession() throws {
        let initialPeripheralSession = sut.peripheralSession
        sut.didTapNavigateToSettings()
        
        #expect(sut.peripheralSession !== initialPeripheralSession)
        #expect(sut.peripheralSession.delegate === sut)
    }
    
    @Test(
        "peripheralSessionDidUpdateState func passes showQRCode when no error"
    )
    func passesShowQRCodeWhenNoError() throws {
        let vc = EmptyViewController()
        let _ = UINavigationController(
            rootViewController: vc
        )
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
        let _ = UINavigationController(
            rootViewController: vc
        )
        sut.presentCredential(Data(), over: vc)
        sut.peripheralSessionDidUpdateState(withError: .notPoweredOn(.poweredOff))
        let qrCodeViewController = try #require(sut.qrCodeViewController)
        #expect(qrCodeViewController.view.subviews.contains(where: {
            $0 is UIButton &&
            ($0 as? UIButton)?.titleLabel?.text == "Go to settings"
        }))
    }
    
    @Test(
        "peripheralSessionDidUpdateState func navigates to error view when given permissions error"
    )
    func navigatesToErrorViewWhenPassedError() throws {
        let vc = EmptyViewController()
        _ = UINavigationController(
            rootViewController: vc
        )
        sut.presentCredential(Data(), over: vc)
        sut.peripheralSessionDidUpdateState(withError: .permissionsNotGranted(.denied))
        
        let navigationController = try #require(sut.navigationController)
        
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        
    }
}

class EmptyViewController: UIViewController {}
