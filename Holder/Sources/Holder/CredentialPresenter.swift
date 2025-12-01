import Bluetooth
import ISOModels
import SharingSecurity
import UIKit

public class CredentialPresenter {
    public var peripheralBluetoothSession = PeripheralSession()
    let sessionDecryption = SessionDecryption()
    let serviceId = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")
    public let deviceEngagement: DeviceEngagement
    
    public func presentCredential(
        _ credential: Data, // raw CBOR credential
        over viewController: UIViewController
    ) {
        
    }
    
    public init() {
        self.deviceEngagement = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite.iso18013,
                eDeviceKey: EDeviceKey(publicKey: sessionDecryption.publicKey)
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: serviceId ?? UUID(),
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
}
