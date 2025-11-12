import Holder
import CoreBluetooth
import Bluetooth
import ISOModels
import SharingSecurity
internal import SwiftCBOR
import UIKit

class QRCodeViewController: UIViewController {
    
    var qrCodeImageView = UIImageView()
    var peripheralAdvertisingManager = PeripheralAdvertisingManager()
    var sessionDecryption = SessionDecryption()
    var deviceEngagement: DeviceEngagement {
        DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite.iso18013,
                eDeviceKey: EDeviceKey(publicKey: sessionDecryption.publicKey)
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: UUID(),
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
            
            let characteristic = CBMutableCharacteristic(
                type: CBUUID(nsuuid: UUID()),
                properties: [.notify],
                value: nil,
                permissions: [.readable, .writeable]
            )
            let descriptor = CBMutableDescriptor(
                type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
                value: "Characteristic"
            )
            characteristic.descriptors = [descriptor]
            
            //TODO: Add CBUUID extension with static values
            let service = CBMutableService(type: CBUUID(string: "F40A40E4-77F5-4CB4-B12F-27D1AD07A871"), primary: true)
            
            service.characteristics = [characteristic]
            service.includedServices = []
            
            _ = peripheralAdvertisingManager.checkBluetooth()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.peripheralAdvertisingManager.addService(service)
                self.peripheralAdvertisingManager.startAdvertising()
            }
            
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
