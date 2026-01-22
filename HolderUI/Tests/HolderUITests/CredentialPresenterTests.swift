import CryptoKit
import ISOModels
import SharingSecurity
import Testing
import UIKit

@testable import HolderUI

@MainActor
@Suite("CredentialPresenter Tests")
struct CredentialPresenterTests {
    var sut: CredentialPresenter
    // swiftlint:disable line_length
    let validSessionEstablishmentBase64 =
    """
    omplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUxy1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfSIVxEDDObsPe2e+zN+mRkYXRhWQLfUq2irL62w5DyygvGWbSEZ465TdRQdDhqreziN3e0RgbkLihGvC4u48HoZ7HRaF5BNUoCGrsP2jbwnPXVxRtWHTvkHJNHrnHPK0nenex7RARqsCJHkxshDJFXhAwVFKYCewiBBxat9hlmNEl5MUrDrp9A5m4BXBJUpoQQi9CT6HcuwzP7Zj/WgDrwLqEL2+g6mZ91tVoYD4chOftXrASs1YyhXsoVDN4cO4SUARiLejDOiH3XtxsS7aL8bsblI1pslJg1H80wHyKSpOu6dVUoXO6E6tlu8Wd7Cvgjn2p6Uq9LiAmx1SqyGhYsoxreIcV70dmXCigyqsQcfVLRxP7k7mQDCiGN9RNjvnAXkvpsUVxIm9Odytb7pI8dbrGenHaVMaO/mZijLAGEEwXyOETKPbah/w0NkXND1i/HKtWOqwGjGYEW8ZYGYJ+U416st40jxZxnhSo2GRX+h4SM26VjDJn6txrv9y0THPRCZU93COxIIWQW8tmWz2z5EBK3cbiJB7HRYp36eUND5lPDEgdILi9mIc1LXc87PDKGJcM/6YvpnF8mSiZDFb5Buv3HJvi83lkg3gpxiE2GCvRMH/Gz14sujXINhdrlP+orP6GAYWKkvgLQOVZ8XrJBnCrYea9I/LffVcqU8bAPYhh/ojKcgieq4BMOwFLKPiEC5X5ykRsyjP3Puq9rk2RmD2E0FTgmRMMMC9TiIsXPlLpac2ecU9XO2VylB4fCKJoMFzWDk8Hg8icjYQAvubFgYGiIpZ73osOJ9ot8tCRXLbAmsXzyvcr8tnyCktkrUAUDVpAKYqgrFvhUdZBSsA8PRnOkYin0Mlfo6DJUAbP+zIxtIli69/fC+7r6s6G2re1Ozqwer9W2ERjfk7wKYisDUE/eR867Ik6YPbEmd+MWwiquBC1s5K2uDYsPQEN7jhr6CFnJUBvrY5dEloWaYPEQabGWW0/6xXealhkfierHyqaIueZ8
    """
    let invalidSessionEstablishmentNoData =  "oWplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUxy1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfSIVxEDDObsPe2e+zN+g=="
    let invalidSessionEstablishmentUnsupportedCurveP384 =
    """
    omplUmVhZGVyS2V52BhYa6QBAiACIVgwAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wIlgwMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl9gZGRhdGFZAt9SraKsvrbDkPLKC8ZZtIRnjrlN1FB0OGqt7OI3d7RGBuQuKEa8Li7jwehnsdFoXkE1SgIauw/aNvCc9dXFG1YdO+Qck0eucc8rSd6d7HtEBGqwIkeTGyEMkVeEDBUUpgJ7CIEHFq32GWY0SXkxSsOun0DmbgFcElSmhBCL0JPody7DM/tmP9aAOvAuoQvb6DqZn3W1WhgPhyE5+1esBKzVjKFeyhUM3hw7hJQBGIt6MM6Ifde3GxLtovxuxuUjWmyUmDUfzTAfIpKk67p1VShc7oTq2W7xZ3sK+COfanpSr0uICbHVKrIaFiyjGt4hxXvR2ZcKKDKqxBx9UtHE/uTuZAMKIY31E2O+cBeS+mxRXEib053K1vukjx1usZ6cdpUxo7+ZmKMsAYQTBfI4RMo9tqH/DQ2Rc0PWL8cq1Y6rAaMZgRbxlgZgn5TjXqy3jSPFnGeFKjYZFf6HhIzbpWMMmfq3Gu/3LRMc9EJlT3cI7EghZBby2ZbPbPkQErdxuIkHsdFinfp5Q0PmU8MSB0guL2YhzUtdzzs8MoYlwz/pi+mcXyZKJkMVvkG6/ccm+LzeWSDeCnGITYYK9Ewf8bPXiy6Ncg2F2uU/6is/oYBhYqS+AtA5VnxeskGcKth5r0j8t99VypTxsA9iGH+iMpyCJ6rgEw7AUso+IQLlfnKRGzKM/c+6r2uTZGYPYTQVOCZEwwwL1OIixc+UulpzZ5xT1c7ZXKUHh8IomgwXNYOTweDyJyNhAC+5sWBgaIilnveiw4n2i3y0JFctsCaxfPK9yvy2fIKS2StQBQNWkApiqCsW+FR1kFKwDw9Gc6RiKfQyV+joMlQBs/7MjG0iWLr398L7uvqzobat7U7OrB6v1bYRGN+TvApiKwNQT95HzrsiTpg9sSZ34xbCKq4ELWzkra4Niw9AQ3uOGvoIWclQG+tjl0SWhZpg8RBpsZZbT/rFd5qWGR+J6sfKpoi55nw=
    """
    
    let invalidSessionEstablishmentMalformedKey =
    """
    omplUmVhZGVyS2V52BhYa6QBAiABIVgwAQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8wIlgwMTIzNDU2Nzg5Ojs8PT4/QEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl9gZGRhdGFZAt9SraKsvrbDkPLKC8ZZtIRnjrlN1FB0OGqt7OI3d7RGBuQuKEa8Li7jwehnsdFoXkE1SgIauw/aNvCc9dXFG1YdO+Qck0eucc8rSd6d7HtEBGqwIkeTGyEMkVeEDBUUpgJ7CIEHFq32GWY0SXkxSsOun0DmbgFcElSmhBCL0JPody7DM/tmP9aAOvAuoQvb6DqZn3W1WhgPhyE5+1esBKzVjKFeyhUM3hw7hJQBGIt6MM6Ifde3GxLtovxuxuUjWmyUmDUfzTAfIpKk67p1VShc7oTq2W7xZ3sK+COfanpSr0uICbHVKrIaFiyjGt4hxXvR2ZcKKDKqxBx9UtHE/uTuZAMKIY31E2O+cBeS+mxRXEib053K1vukjx1usZ6cdpUxo7+ZmKMsAYQTBfI4RMo9tqH/DQ2Rc0PWL8cq1Y6rAaMZgRbxlgZgn5TjXqy3jSPFnGeFKjYZFf6HhIzbpWMMmfq3Gu/3LRMc9EJlT3cI7EghZBby2ZbPbPkQErdxuIkHsdFinfp5Q0PmU8MSB0guL2YhzUtdzzs8MoYlwz/pi+mcXyZKJkMVvkG6/ccm+LzeWSDeCnGITYYK9Ewf8bPXiy6Ncg2F2uU/6is/oYBhYqS+AtA5VnxeskGcKth5r0j8t99VypTxsA9iGH+iMpyCJ6rgEw7AUso+IQLlfnKRGzKM/c+6r2uTZGYPYTQVOCZEwwwL1OIixc+UulpzZ5xT1c7ZXKUHh8IomgwXNYOTweDyJyNhAC+5sWBgaIilnveiw4n2i3y0JFctsCaxfPK9yvy2fIKS2StQBQNWkApiqCsW+FR1kFKwDw9Gc6RiKfQyV+joMlQBs/7MjG0iWLr398L7uvqzobat7U7OrB6v1bYRGN+TvApiKwNQT95HzrsiTpg9sSZ34xbCKq4ELWzkra4Niw9AQ3uOGvoIWclQG+tjl0SWhZpg8RBpsZZbT/rFd5qWGR+J6sfKpoi55nw=
    """
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
    
    @Test(
        "decodeMessage successfully throws an error when given unsupported curve value"
    )
    func thrownErrorForUnsupportedCurve() async throws {
        let curve = Curve.p384
        #expect(
            throws: DecryptionError
                .computeSharedSecretCurve("\(curve) (\(curve.rawValue))")
        ) {
            try sut.decodeMessage(
                #require(
                    Data(
                        base64Encoded: invalidSessionEstablishmentUnsupportedCurveP384
                    )
                )
            )
        }
    }
    
    @Test(
        "decodeMessage successfully throws an error when given malformed key value"
    )
    func thrownErrorForMalformedKey() async throws {
        #expect(
            throws: DecryptionError
                .computeSharedSecretMalformedKey(CryptoKitError.incorrectParameterSize)
        ) {
            try sut.decodeMessage(
                #require(
                    Data(
                        base64Encoded: invalidSessionEstablishmentMalformedKey
                    )
                )
            )
        }
    }
}

class EmptyViewController: UIViewController {}
