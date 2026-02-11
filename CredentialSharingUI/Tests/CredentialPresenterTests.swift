import CryptoKit
import CryptoService
import Testing
import UIKit

@testable import CredentialSharingUI

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
    
    // MARK: - PeripheralSessionDidReceiveMessageData tests
    @Test(
        "decodeMessage successfully decodes valid CBOR SessionEstablishment message"
    )
    func successfullyDecodeSessionEstablishment() async throws {
        try sut
            .peripheralSessionDidReceiveMessageData(
                #require(Data(base64Encoded: validSessionEstablishmentBase64))
            )
    }
    
    @Test("peripheralSessionDidReceiveMessageData successfully shows an error when given invalid sessionEstablishment data")
    func showsErrorForInvalidSessionEstablishmentData() async throws {
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
                $0 is UILabel && ($0 as? UILabel)?.text == "\(SessionEstablishmentError.cborDataFieldMissing.errorDescription)"
            })
        )
        #expect(mockQRCodeViewController.viewControllerWasDismissed)
    }
    
    @Test(
        "computeSharedSecret successfully shows an error when given unsupported curve value"
    )
    func showsErrorForUnsupportedCurve() async throws {
        // Given
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        let mockQRCodeViewController = QRCodeViewControllerTests.TestableQRCodeViewController()
        sut.qrCodeViewController = mockQRCodeViewController
        
        // When
        let curve = Curve.p384
        try sut.peripheralSessionDidReceiveMessageData(
            #require(
                Data(
                    base64Encoded: invalidSessionEstablishmentUnsupportedCurveP384
                )
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
                $0 is UILabel && ($0 as? UILabel)?.text == "\(DecryptionError.computeSharedSecretCurve("\(curve) (\(curve.rawValue))").errorDescription)"
            })
        )
        #expect(mockQRCodeViewController.viewControllerWasDismissed)
    }
    
    @Test(
        "computeSharedSecret successfully throws an error when given malformed key value"
    )
    func thrownErrorForMalformedKey() async throws {
        // Given
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        let mockQRCodeViewController = QRCodeViewControllerTests.TestableQRCodeViewController()
        sut.qrCodeViewController = mockQRCodeViewController
        
        // When
        try sut.peripheralSessionDidReceiveMessageData(
            #require(
                Data(
                    base64Encoded: invalidSessionEstablishmentMalformedKey
                )
            )
        )

        let navigationController = try #require(sut.navigationController)
        let errorViewController = try #require(navigationController.viewControllers.first(where: { (type(of: $0) == ErrorViewController.self) }))
        
        // Then
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        let error = CryptoKitError.incorrectParameterSize
        #expect(
            errorViewController.view.subviews.contains(where: {
                $0 is UILabel && ($0 as? UILabel)?.text == "\(DecryptionError.computeSharedSecretMalformedKey(error).errorDescription)"
            })
        )
        #expect(mockQRCodeViewController.viewControllerWasDismissed)
    }
    
    @Test("computeSharedSecret doesn't throw error when decrypting valid data")
    func computeSharedSecretDoesntThrowErrorWhenDecryptingData() async throws {
        let vc = EmptyViewController()
        _ = UINavigationController(rootViewController: vc)

        sut.presentCredential(Data(), over: vc)
        
        #expect(throws: Never.self) {
            try sut.peripheralSessionDidReceiveMessageData(
                #require(
                    Data(
                        base64Encoded: validSessionEstablishmentBase64
                    )
                )
            )
        }
    }
}

let sessionEstablismentData = "a16464617461590dfa46da5fb292a7880af38f2e4d9eb23ecac231ad21dfe81e3b5c21e7f3d2b5a2d4676dd13331112f0fba678275dc2fcd889150a7bbb333b7ecf5f35fc8b2e4aee701651a4bdc93cd25bc533582647507b5b9a075deaf7e1ef035acb3c8b403ac6e51a19d4289381035199da169b5ab175d8bc2075ac73dbaa76aa79d9a26ac3930034515525c413110abaeae731545b36400205f3130e902242db99066a04ab6cef9d14672c3dfe467802e5364dff5535c8c36fdb53afde285ee9462f72a4f8b5707879590d8b5ee83a3068c1c25f13681085cf4a5af3cb2e77bcc7cae6def76ab5ad119e6db563799d15af9f5861b7ec0003c68fa46f12ca366263b5fe5bb8f5b16bede1e5e5919abf8b675fb10ce4655815fe6a3582ec44e0c93f0cf3a5ea1ca2e476113b47bc1ff2484f791c68385cd5ff3f1f27f70a88c7c649581e59a5bb2371d6268704526bf1b16cd36d9e739bef50a199deafb8ceadd42c260e58688bd569b420f32ad0502e6dff9346440459febbb49d843e50e93d46c0fd2125d4131e1d528435110b5e0db9e41795716422dc895425773eae490fbfba7c10f85ec364bdfac7de120ba4883142e854bf19510f969be690fad9a3f7197885dcb44bd9028998adf6e95356af058e4c20502b5c4d3c4c52469727042e75e0ca8e43efb590da9a1a1cc3ffdd03a422e7589ec237c36c0d5587ab853ab39be4388cdd9feb7b763ecb6344172fafde86a9501975dd86f19f095f98a1e65ace933e8723db8f1e5074f7c9c0415e4e69f12c2a6c14c0ca09c872f2ac83e0ec7294e6dc4f1fa087d48201c9c68d1cef4b793fb97b374505b348e090207a179305347599060200a1f398e9d9aa2eadbe31ee0172b25d1f0b1287b3aad8f1afa560981c6490a1aec1052f47201ab5baed0ecf826c7b2b416ce0c2e265403a922f80d1cf6842a7182c8bbe7a138096cb1fcffcfc102d16d08cbf86108393ef8276120e9341c11c5e5e1cebc257b697d2182ed1ead67d7e5814a3f9b380cf917ccf59921f4ae545a14a8ec0f8642b7bd5565039b60546efb2c68aa0ac2d3f972386cd9f47280e2f27af727335cd6ca1aec25c2ad2d079cd3fb045ccbaf6f4a5b0a80e07795f5790ff53aaefdf3a63240ca7e9d5658ce84a21d310463335cf1f6015dc89ee54d687abcd4787c060a0bce53020b1c6a5bb6c3ea4d759b7f3eddabcaade785c23caa9ba15272724e0589cef502d80085bd77bae93897b01e2588ddd504aebe8333a153790a9699748a4269f5017c81aaf8061f9985e0cf7553b4c4d0a5c401f20f0ab6d85078728676bcfdc9c1a1bc4dea2b01c68e0bb7bf8ada66aa93fc322673efa3895b09d085a0cd085dab3018a9e032acd3d715bf190c629fc55d55ed815b0ba56e83f78c453165c024ca5b2de5b4accfbab07aa1c482b8e960db03652167f903db0ecf03ef85834951a603c3e6069210744d70c5875e50badb91dcc8beca4945b869e73e535a7967fbcb377ce861f07e537349c8a33793c0c05c1b4dd220634e1f52f6701d79d83f99311d6c1463ea3bbcf4d1a7614cbedfceafa1e874b84e6b30698551c6da9f8487fc5270cd5dc73f9aa9dc8a513b1514d7abb0bec4d2cd06b14efd23f3c59602fcfc5d9aecf48148128ca86d6d4ebbe2f68460db00a49759887a478a1eccdd8b426aa130d8b7da0e331415a9682d7125e56285a927f54ac5139a3f8d78c2dc6ffa0bc9ad4db749e8dae10169aa6be9206b635943b7a0970a23e04a2ba66712365b2ea0afb0422a0224592074f723781b8df86627296f9f126f94efe089f8db5f2eea4f28673e11ccd80726901ee1bcc8fa49b6f65c0f8587222f2bb81744a3ece2f74ac21e8c5805d054f93e2d669616ecbc07f3d017a36b951aecd28a14ada87e4f935ef7f93c2c7d01cedf5658131908e4d36aa4690ba952d3f7fa25b6a8481d42f6a7794c8b1dd4de2f7e6bb3ed6fd3915591997e06f01715bac3cdfb0885ce97136e4b7b4b1e6685fd42de1e8ae610523c2b2603977cf3c45058802d734322a9aa0181ff1231b4674071e5c75d8f11e56d67916b4d5f7a9b42a26519c990fdb728630f0755cf8fc0d177c24e1375cc793cee463da5dbef1fe6a835bf75317052b7b077d397c7b617a632371d22eb64c91f91d8fdf5aa3345f0e6e7a0d42e8da52087a89428a1241b4527d5f4d3751b10d40e8768bc6b1a55b531a9e8fb9afdfaf3aed0a3bc71b9c432b89da34e4685b8b48f650394e760270df2c837ab51ded999b903c0f9630478adb8843e462ad8123466ff837dc18241db341ecabbc0a8693bd35831d49c09adf8c5d7c4f80b3628b633d46a93c2b7b61e5127abb5e877e6904de7049a53213b357cdb443c31bababdc0480fe6986951ea9d684e53f5b53871e80148afc30c4e2eed05a0aeafa0b98f98e8ffbad6af968ecfd286b24c43bf2b54e64e28fab328d791bbf80292e2226dfc7d0d562b511321b6b501eadbd1661f028bad02e37575104f646222484aac1548a762cfec36b9597a4e7309497b49f1921a948a597cc7d721f6396389aaffd2828da0443e4f2354cf2fbe69c0a2a8f3d2271207440e95445a4fb24de95d5232e66ff84c8e1ab5c5576e316ce3e78d7c0047695ef0037cc7f7d0f21fa53a1976a7e1bb2d70751c6ebebb5fd24dad9fa58ffee261b0ee7a55a86a6236901feb322400965313175a263e5b8437eb2a7ddf239d15c27b2e8b55abccd7574df807f3e8483670aac580fec1bbeb779a3cb2e89440e8badccdcdccf6f6e7dd9a2d62080c7057824ede7186f924e2c59934a0fc0d518d05ff48da1b012322bb55d2493a850954b6af585e72f5bef55180f9fc293e40bd48a261cee4099ad4674541ddb5a81683034e9e31f59c8942321f09a5ed1e11854b6cd8af4afcf919f2001722c2396b9b30e1c5d8182061bb39201477a0538db896a399493151b1f6162284284b8cc42701fad81c63846f0d7e3be5004a3d1e5dc047c2b28d7c28940e70ba52ac7aa0de584a9ff7859aa0e9af8d24d5dcfd07cf5c6fd8034e2a3ef63b41be59ab93d941cee00b3029478181e576d3b0c09f28b1c70ab7c2e622e7cacb2f6d2337c430afa5736169bddfe379f5b3d3392cfaa1bc45f6d3e47e73678ec19cecb20b3aee82378e41f84b59c172abc8d40370f8bb833f8edca890cd4f85f5610d3e208bada4deb6f15d9cb0a9f805b1f9915e40bed12ed2494886801d6ff83df037b4a245d03489fa7dda552dccbd11b84101c4147595e0ee6d89b5d7621492d21dc01b5afc1ce3c65cc878d823810f7d0c4232374a4e82013ad3a99f2422aa8e4e2cc33c66dc5b07bd2ece416999563a6f2e62ef367904990f1442519eb00c6eecb1c886bde5613dba37908cc79f71bcfbf5fb96142488f0be69c510e144bd1a25f2e6f22bf78cc213d7ba83def9146224b67c1ca5cad8520e55d1b01daaa70475caa1e4ed117ac8952a3f4566edd28e599b59a3be80405bedf150e5d5dd4d0f3d1d84e8e7f7dfe945d358493bb119470aabbf5b3eb7205f2184793e5f9b41c0c622ebf0b83730feb3c2d06de8f7992cee469bf104595cd98307f7d3d584760b6f1d75e10f51325626627050f5b636f34b93471c290b1afede150055b796d3d08f31b52360ef28630acc273bfcda6aa14df76867cc230c0597bd76105d7a54426698d87ad1ac683c7569b80f0f4c5d169dd0dbcf390e8449b698649183cdf214a13e51ed5c5c38df9931ad23a05e49b85975bcc65cca5ebfb404f62552cf46fd535e5d9e8178dff0156fbd6227e2e04c56af73e8a149dbd63f5cd0a5ec1046c30b3a25ba60cfc869df084553430e7058e948b8e426003421988789c266fcf9f6c309fcc785e11e76121316f82b61555352c91f3d936dbc1e181a6924d480ba09a62adf930dee5884ce5362ff31f1e2a4558702bc0d8c871cc322efad66efc946c3a9ae959ef20c052787d6a5e04d7dc9dfc2c9941104ad26c136a9827a866b9e0942dbacd4aed56b48547c6dc1d0216fcdd2b5ce40828bdae5df48e724232b01cc567173e07b9089e7834bb92c873c5e08ba055698df5f79ee73e122b5b72ee3e2e100858dad409da55ad0fa1aa9caa60bf9c25e9ba3e1dc012724c89903a820b63dd5f14f0019007b180684afbe125a0cf87af796ae20e465641c5e8fb91b6e7c6395d2f49f17bac3e35110c16b119bf289e11afb4bbae40266aa87605298ec5bb0601fa415038621ea100db5d9d8a5da4d74fd92ed882546afc7a8a3dc648b1c7852e8fa43ca9ed287a4bb9dd299bfc69414f990bf3b7b58a932a4ff9c86e2fb131b7cc7b65464cc80011267ab49f5c599b9ce43acc9a06b856b25b6fe5f51afd6db147386a1ab30575a0eae607ffe116cae7fb70df6841ae0f52eaf359305becdf7f4636f3c31fab45387ef97cef0b8ef6a8de702a2f1c21c3aee10382e8b8610a03bf6f1c54527a1d6db79f80f71c7f29880bb4b0d46cee3a6063028e901f2f3514639bce237259a3122beea38763e205263f663543bf9bb390337f6a992b74dbfab966a9abf3dd54b15956b47ee731d23ec9a87a0027ed16f6fc4384812df153231c61331ef22e16035719044fddd7b6a9626aa8397073d0cbf42fffd2b8201dca65aadaf98048e7bc0917ed83c7cbb59086ceff885b523fca2d65d87323fd6bbd75b0a312b317b217985334086a63cdc4f065be41dfc590c76d71f93f76c091ee6b2878c2d718adde4493eef3a4cb8b2764e7013b80f922bf2b3b3572029975bc1388b7c975f353a02fa01ab679bbe041041dc1425787606df44013b7627c4d43b1edbda3768386f2b9a78470ac7ac5ca6b2d20385d53e2e412828e2ebcdd17ce8658c655babeefe0b2f43f606a192613263a2c27831a7c5953c9a1f2910093b4720e78e3b34ae7102e1094fcc6655d3af6d9a4c8f58f2478ef532121b7c91fe558a80257d63d8e9b4300c09dc04d9d37975f5cf3e548f23e40c070822419a74267d08453815ba8e02943c3bc5a13ad669fd79d8e4ee5f5be82dc638ba9a1d"
class EmptyViewController: UIViewController {}
