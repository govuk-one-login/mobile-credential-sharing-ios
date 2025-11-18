import Bluetooth
import CoreBluetooth
import Holder
import ISOModels
import SharingSecurity
internal import SwiftCBOR
import UIKit

class QRCodeViewController: UIViewController {
    
    var qrCodeImageView = UIImageView()
    var peripheralAdvertisingManager = PeripheralAdvertisingManager()
    var sessionDecryption = SessionDecryption()
    let serviceId = UUID()
    var cbUUID: CBUUID {
        // Hard coding the UUID for now, for easier tracking
        CBUUID(string: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")
    }
    var deviceEngagement: DeviceEngagement {
        DeviceEngagement(
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
    }
    
    deinit {
        peripheralAdvertisingManager.stopAdvertising()
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
            
            initiateBLEAdvertising()
            
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
    
    private func initiateBLEAdvertising() {
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
        
        let service = CBMutableService(type: cbUUID, primary: true)
        
        service.characteristics = [characteristic]
        service.includedServices = []
        
        // Used to prompt initial bluetooth permission check
        _ = peripheralAdvertisingManager.checkBluetooth()
        
        peripheralAdvertisingManager.removeServices()
        peripheralAdvertisingManager.addService(service)
        peripheralAdvertisingManager.beginAdvertising = true
    }
}
