import Bluetooth
import CoreBluetooth
import Holder
import ISOModels
import SharingSecurity
internal import SwiftCBOR
import UIKit

class QRCodeViewController: UIViewController {
    
    var qrCodeImageView = UIImageView()
    var peripheralAdvertisingManager = PeripheralSession()
    var sessionDecryption = SessionDecryption()
    let serviceId = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")
    var deviceEngagement: DeviceEngagement {
        DeviceEngagement(
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
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "QR Code"
        navigationController?.navigationBar.titleTextAttributes = [.font: UIFont.systemFont(
            ofSize: 24,
            weight: .bold
        )]
        
        view.backgroundColor = .systemBackground
        
        print(
            "the base64 encoded CBOR is: ",
            Data(deviceEngagement.toCBOR().encode()).base64EncodedString()
        )
        
        print("The public key is: ", sessionDecryption.publicKey)
        print("The private key is: ", sessionDecryption.privateKey)
        
        do {
            try setupQRCode()
        } catch {
            fatalError("Unable to create QR code")
        }
    }
    
    private func setupQRCode() throws {
        do {
            let qrCode: UIImage = try QRGenerator(data: Data(deviceEngagement.toCBOR().encode())).generateQRCode()
            qrCodeImageView.image = qrCode
            view.addSubview(qrCodeImageView)
        } catch {
            throw QRCodeGenerationError.unableToCreateImage
        }
        
        qrCodeImageView.translatesAutoresizingMaskIntoConstraints = false
        qrCodeImageView.contentMode = .scaleAspectFit
        
        NSLayoutConstraint.activate(
            [
                qrCodeImageView.centerYAnchor
                    .constraint(equalTo: view.centerYAnchor),
                qrCodeImageView.centerXAnchor
                    .constraint(equalTo: view.centerXAnchor),
                qrCodeImageView.widthAnchor
                    .constraint(
                        lessThanOrEqualTo: view.widthAnchor,
                        multiplier: 0.75
                    ),
                qrCodeImageView.heightAnchor
                    .constraint(
                        lessThanOrEqualTo: qrCodeImageView.widthAnchor,
                        multiplier: qrCodeImageView.image!.size.height / qrCodeImageView.image!.size.width
                    )
            ]
        )
    }
}
