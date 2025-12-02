import Bluetooth
import Holder
import ISOModels
import SharingSecurity
import UIKit

public class CredentialPresenter: @MainActor PeripheralSessionDelegate, @MainActor QRCodeViewControllerDelegate {
    public var peripheralSession: PeripheralSession
    let sessionDecryption = SessionDecryption()
    let serviceId: UUID
    public let deviceEngagement: DeviceEngagement
    var viewController: QRCodeViewController?
    
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
            let qrCode: UIImage = try QRGenerator(data: Data(deviceEngagement.toCBOR().encode())).generateQRCode()

            self.peripheralSession.delegate = self
            self.viewController = QRCodeViewController(qrCode: qrCode)
            self.viewController?.delegate = self
        } catch {
            print(QRCodeGenerationError.unableToCreateImage.localizedDescription)
        }
        guard let navigationController = viewController.navigationController,
              self.viewController != nil else {
            fatalError(
                "Error: HomeViewController is not embedded in a UINavigationController."
            )
        }
        navigationController
            .pushViewController(self.viewController!, animated: true)
    }
    
    @MainActor
    public func didTapNavigateToSettings() {
        self.peripheralSession = PeripheralSession(serviceUUID: serviceId)
        self.peripheralSession.delegate = self
    }
    
    @MainActor
    public func peripheralSessionDidUpdateState(withError error: Bluetooth.PeripheralError?) {
        if error != nil {
            viewController?.showSettingsButton()
        } else {
            viewController?.showQRCode()
        }
    }
}
