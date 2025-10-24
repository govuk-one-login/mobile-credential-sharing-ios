import Holder
import ISOModels
internal import SwiftCBOR
import UIKit

class QRCodeViewController: UIViewController {
    
    var qrCodeImageView = UIImageView()
    let deviceEngagement = DeviceEngagement(
        security: Security(
            cipherSuiteIdentifier: CipherSuite.iso18013,
            eDeviceKey: EDeviceKey(
                curve: .p256,
                xCoordinate: [],
                yCoordinate: []
            )
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "QR Code"
        navigationController?.navigationBar.titleTextAttributes = [.font: UIFont.systemFont(
            ofSize: 24,
            weight: .bold
        )]
        
        view.backgroundColor = .systemBackground
        
        // swiftlint:disable:next line_length
        print(
            "the base64 encoded CBOR is: ",
            Data(deviceEngagement.toCBOR().encode()).base64EncodedString()
        )
        
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
