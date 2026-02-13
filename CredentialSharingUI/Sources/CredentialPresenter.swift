import BluetoothTransport
import CoreBluetooth
import CryptoKit
import CryptoService
import UIKit

@MainActor
public protocol CredentialPresenting: AnyObject {
    func presentCredential(_ data: Data, over viewController: UIViewController)
}

extension CredentialPresenter: CredentialPresenting {}

@MainActor
public class CredentialPresenter {
    public var peripheralSession: PeripheralSession?
    public var deviceEngagement: DeviceEngagement?
    var sessionDecryption: SessionDecryption?
    fileprivate var cryptoService: CryptoService?
    var qrCodeViewController: QRCodeViewController?
    var baseViewController: UIViewController? {
        didSet {
            guard baseViewController?.navigationController != nil else {
                fatalError(
                    "Error: baseViewController is not embedded in a UINavigationController."
                )
            }
            navigationController = baseViewController?.navigationController
        }
    }
    var navigationController: UINavigationController?

    public init() {
        // Empty init required to declare class as public facing
    }
    
    private func createPeripheralSession(with credential: Data) -> PeripheralSession {
        let serviceId = UUID()
        
        let peripheralSession = PeripheralSession(serviceUUID: serviceId)
        sessionDecryption = SessionDecryption()
        guard let sessionDecryption else {
            fatalError("SessionDecryption was not initialized correctly.")
        }
        cryptoService = CryptoService(sessionDecryption: sessionDecryption)
        self.deviceEngagement = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite.iso18013,
                eDeviceKey: EDeviceKey(publicKey: sessionDecryption.publicKey)
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: serviceId
                    )
                )
            )]
        )
        print(
            "the base64 encoded CBOR is: ",
            Data(deviceEngagement.toCBOR().encode()).base64EncodedString()
        )

        print("The public key is: ", sessionDecryption.publicKey)
        print("The private key is: ", sessionDecryption.privateKey)
        
        return peripheralSession
    }

    @MainActor
    public func presentCredential(
        _ credential: Data,  // raw CBOR credential
        over viewController: UIViewController
    ) {
        do {
            peripheralSession = createPeripheralSession(with: credential)
            baseViewController = viewController
            let qrCode: UIImage = try QRGenerator(data: Data(deviceEngagement.toCBOR().encode())).generateQRCode()

            peripheralSession?.delegate = self
            self.qrCodeViewController = QRCodeViewController(qrCode: qrCode)
            self.qrCodeViewController?.delegate = self
        } catch {
            print(
               error.localizedDescription
            )
        }
        
        guard let navigationController,
              self.qrCodeViewController != nil
        else {
            fatalError(
                "Error: baseViewController is not embedded in a UINavigationController."
            )
        }
        navigationController
            .present(self.qrCodeViewController!, animated: true)
    }
}

extension CredentialPresenter: @MainActor PeripheralSessionDelegate {
    @MainActor
    public func peripheralSessionDidUpdateState(
        withError error: PeripheralError?
    ) {
        switch error {
        case .permissionsNotGranted:
            navigateToErrorView(titleText: "Permission permanently denied")
        case .notPoweredOn:
            qrCodeViewController?.showSettingsButton()
        case .connectionTerminated:
            navigateToErrorView(titleText: error?.errorDescription ?? "")
        case .failedToNotifyEnd:
            navigateToErrorView(titleText: "BLE_ERROR")
        case nil:
            peripheralSession?.startAdvertising()
        default:
            break
        }
    }
    
    public func peripheralSessionDidStartAdvertising() {
        qrCodeViewController?.showQRCode()
    }
    
    public func peripheralSessionDidReceiveMessageData(_ messageData: Data) {
        do {
            guard var cryptoService,
                  let deviceEngagement else {
                navigateToErrorView(titleText: "cryptoService or deviceEngagement cannot be nil")
                return
            }
            try cryptoService.decryptSessionEstablishmentMessage(from: messageData, with: deviceEngagement)
        } catch let error as SessionEstablishmentError {
            navigateToErrorView(titleText: error.errorDescription)
        } catch COSEKeyError.unsupportedCurve(let curve) {
            navigateToErrorView(titleText: DecryptionError.computeSharedSecretCurve("\(curve) (\(curve.rawValue))")
                .errorDescription)
        } catch COSEKeyError.malformedKeyData(let error) {
            navigateToErrorView(titleText: DecryptionError
                .computeSharedSecretMalformedKey(error).errorDescription)
        } catch {
            navigateToErrorView(titleText: "Unknown Error")
        }
    }

    public func peripheralSessionDidReceiveMessageEndRequest() {
        qrCodeViewController?.dismiss(animated: true)
        navigateToErrorView(titleText: "Session ended by reader")
    }
}

extension CredentialPresenter: @MainActor QRCodeViewControllerDelegate {
    public func didTapCancel() {
        self.peripheralSession?.endSession()
    }

    public func didTapNavigateToSettings() {
        // Creates an unused CBPeripheralManager, which forces the system pop-up to navigate user to settings
        _ = CBPeripheralManager(
            delegate: nil,
            queue: nil,
            options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    private func navigateToErrorView(titleText: String) {
        qrCodeViewController?.dismiss(animated: false)
        let errorViewController = ErrorViewController(titleText: titleText)
        navigationController?.pushViewController(errorViewController, animated: true)
    }
}
