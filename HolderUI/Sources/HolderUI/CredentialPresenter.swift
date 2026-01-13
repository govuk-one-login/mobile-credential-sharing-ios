import Bluetooth
import CoreBluetooth
import Holder
import ISOModels
import SharingSecurity
import UIKit

@MainActor
public protocol CredentialPresenting {
    func presentCredential(_ data: Data, over viewController: UIViewController)
}

extension CredentialPresenter: CredentialPresenting {}

@MainActor
public class CredentialPresenter: @MainActor PeripheralSessionDelegate, @MainActor QRCodeViewControllerDelegate {
    public var peripheralSession: PeripheralSession?
    public var deviceEngagement: DeviceEngagement?
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
        let sessionDecryption = SessionDecryption()

        self.deviceEngagement = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite.iso18013,
                eDeviceKey: EDeviceKey(publicKey: sessionDecryption.publicKey)
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: serviceId,
                        address: "mock-address"
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
        _ credential: Data, // raw CBOR credential
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
            print(QRCodeGenerationError.unableToCreateImage.localizedDescription)
        }
        
        guard navigationController != nil,
              self.qrCodeViewController != nil else {
            fatalError(
                "Error: baseViewController is not embedded in a UINavigationController."
            )
        }
        navigationController?.present(self.qrCodeViewController!, animated: true)
    }
    
    @MainActor
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
    
    @MainActor
    public func peripheralSessionDidUpdateState(
        withError error: Bluetooth.PeripheralError?
    ) {
        switch error {
        case .permissionsNotGranted:
            navigationController?.popToRootViewController(animated: false)
            navigationController?
                .pushViewController(
                    ErrorViewController(
                        titleText: "Permission permanently denied"
                    ),
                    animated: true
                )
        case .notPoweredOn:
            qrCodeViewController?.showSettingsButton()
        case nil:
            qrCodeViewController?.showQRCode()
        default:
            break
        }
    }
}
