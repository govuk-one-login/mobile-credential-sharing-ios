import Bluetooth
import CoreBluetooth
import Holder
import ISOModels
import SharingSecurity
internal import SwiftCBOR
import UIKit

class QRCodeViewController: UIViewController, PeripheralBluetoothSessionDelegate {
    var qrCodeImageView = UIImageView()
    var peripheralBluetoothSession = PeripheralSession()
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
        peripheralBluetoothSession.delegate = self
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
        
        updateUI()
    }
    
    func bluetoothSessionDidUpdateState() {
        updateUI()
    }
    
    private func updateUI() {
        if peripheralBluetoothSession.error == .bluetoothNotEnabled {
            setupNavigateToSettingsButton()
        } else {
            do {
                try setupQRCode()
            } catch {
                fatalError("Unable to create QR code")
            }
        }
    }
    
    private func setupNavigateToSettingsButton() {
        let navigateButton = UIButton(type: .system)
        navigateButton.configuration = .bordered()
        navigateButton.configuration?.baseBackgroundColor = .systemGreen
        navigateButton.configuration?.baseForegroundColor = .white
        navigateButton.configuration?.contentInsets = .init(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
            
        navigateButton.setTitle("Go to settings to enable bluetooth", for: .normal)
        navigateButton.titleLabel?.font = UIFont
            .preferredFont(forTextStyle: .headline)
        navigateButton.translatesAutoresizingMaskIntoConstraints = false
        navigateButton
            .addTarget(
                self,
                action: #selector(navigateButtonTapped),
                for: .touchUpInside
            )
        
        qrCodeImageView.removeFromSuperview()
        view.addSubview(navigateButton)

        NSLayoutConstraint.activate([
            navigateButton.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            navigateButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func navigateButtonTapped() {
        peripheralBluetoothSession = PeripheralSession()
        peripheralBluetoothSession.delegate = self
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
