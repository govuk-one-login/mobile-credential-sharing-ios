import ISOModels
import Testing
import UIKit

@testable import HolderUI

@MainActor
@Suite("CredentialPresenter Tests")
struct CredentialPresenterTests {
    var sut: CredentialPresenter
    // swiftlint:disable line_length
    let sessionEstablishmentBase64 =
    """
    omplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUxy1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfSIVxEDDObsPe2e+zN+mRkYXRhWQLfUq2irL62w5DyygvGWbSEZ465TdRQdDhqreziN3e0RgbkLihGvC4u48HoZ7HRaF5BNUoCGrsP2jbwnPXVxRtWHTvkHJNHrnHPK0nenex7RARqsCJHkxshDJFXhAwVFKYCewiBBxat9hlmNEl5MUrDrp9A5m4BXBJUpoQQi9CT6HcuwzP7Zj/WgDrwLqEL2+g6mZ91tVoYD4chOftXrASs1YyhXsoVDN4cO4SUARiLejDOiH3XtxsS7aL8bsblI1pslJg1H80wHyKSpOu6dVUoXO6E6tlu8Wd7Cvgjn2p6Uq9LiAmx1SqyGhYsoxreIcV70dmXCigyqsQcfVLRxP7k7mQDCiGN9RNjvnAXkvpsUVxIm9Odytb7pI8dbrGenHaVMaO/mZijLAGEEwXyOETKPbah/w0NkXND1i/HKtWOqwGjGYEW8ZYGYJ+U416st40jxZxnhSo2GRX+h4SM26VjDJn6txrv9y0THPRCZU93COxIIWQW8tmWz2z5EBK3cbiJB7HRYp36eUND5lPDEgdILi9mIc1LXc87PDKGJcM/6YvpnF8mSiZDFb5Buv3HJvi83lkg3gpxiE2GCvRMH/Gz14sujXINhdrlP+orP6GAYWKkvgLQOVZ8XrJBnCrYea9I/LffVcqU8bAPYhh/ojKcgieq4BMOwFLKPiEC5X5ykRsyjP3Puq9rk2RmD2E0FTgmRMMMC9TiIsXPlLpac2ecU9XO2VylB4fCKJoMFzWDk8Hg8icjYQAvubFgYGiIpZ73osOJ9ot8tCRXLbAmsXzyvcr8tnyCktkrUAUDVpAKYqgrFvhUdZBSsA8PRnOkYin0Mlfo6DJUAbP+zIxtIli69/fC+7r6s6G2re1Ozqwer9W2ERjfk7wKYisDUE/eR867Ik6YPbEmd+MWwiquBC1s5K2uDYsPQEN7jhr6CFnJUBvrY5dEloWaYPEQabGWW0/6xXealhkfierHyqaIueZ8
    """
    let invalidSessionEstablishmentNoData =  "oWplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUxy1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfSIVxEDDObsPe2e+zN+g=="
    // swiftlint:enable line_length

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
    
    @Test(
        "decodeMessage successfully decodes valid CBOR SessionEstablishment message"
    )
    func successfullyDecodeSessionEstablishment() async throws {
        try sut
            .peripheralSessionDidReceiveMessageData(
                #require(Data(base64Encoded: sessionEstablishmentBase64))
            )
    }
    
    @Test("peripheralSessionDidSendFullMessage successfully throws an error when given invalid data")
    func throwsErrorForInvalidData() async throws {
        // Given
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        let mockQRCodeViewController = QRCodeViewControllerTests.TestableQRCodeViewController()
        sut.qrCodeViewController = mockQRCodeViewController
        
        // When
        try sut.peripheralSessionDidReceiveMessageData(
            #require(
                Data(base64Encoded: invalidSessionEstablishmentNoData)
            )
        )

        let navigationController = try #require(sut.navigationController)
        let errorViewController = try #require(navigationController.viewControllers.first(where: { (type(of: $0) == ErrorViewController.self) }))
        
        // Then
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        #expect(
            errorViewController.view.subviews.contains(where: {
                $0 is UILabel && ($0 as? UILabel)?.text == SessionEstablishmentError.cborDataFieldMissing.errorDescription
            })
        )
        #expect(mockQRCodeViewController.viewControllerWasDismissed)
    }
}

class EmptyViewController: UIViewController {}
