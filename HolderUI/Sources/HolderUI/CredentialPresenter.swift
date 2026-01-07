import Bluetooth
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
    public var peripheralSession: PeripheralSession
    let sessionDecryption = SessionDecryption()
    let serviceId: UUID
    public let deviceEngagement: DeviceEngagement
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
        #if DEBUG
            serviceId = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")!
        #else
            serviceId = UUID()
        #endif

        peripheralSession = PeripheralSession(serviceUUID: serviceId)
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
    }
    
    @MainActor
    public func presentCredential(
        _ credential: Data, // raw CBOR credential
        over viewController: UIViewController
    ) {
        do {
            baseViewController = viewController
            let qrCode: UIImage = try QRGenerator(data: Data(deviceEngagement.toCBOR().encode())).generateQRCode()

            self.peripheralSession.delegate = self
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
        navigationController?
            .pushViewController(self.qrCodeViewController!, animated: true)
    }
    
    @MainActor
    public func didTapNavigateToSettings() {
        self.peripheralSession = PeripheralSession(serviceUUID: serviceId)
        self.peripheralSession.delegate = self
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
