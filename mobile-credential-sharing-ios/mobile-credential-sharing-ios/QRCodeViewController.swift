import Bluetooth
import CoreBluetooth
import Holder
import ISOModels
import SharingSecurity
internal import SwiftCBOR
import UIKit

class QRCodeViewController: UIViewController {
    
    var qrCodeImageView: UIImageView
    let serviceId: UUID
    let peripheralSession: PeripheralSession
    let sessionDecryption: SessionDecryption
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
    
    init(qrCodeImageView: UIImageView = UIImageView(), sessionDecryption: SessionDecryption = SessionDecryption()) {
        self.qrCodeImageView = qrCodeImageView
        self.sessionDecryption = sessionDecryption
        
        #if DEBUG
        serviceId = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")!
        #else
        serviceId = UUID()
        #endif
        
        peripheralSession = PeripheralSession(serviceUUID: serviceId)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        peripheralSession.delegate = self
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
        if peripheralSession.error == .bluetoothNotEnabled {
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
            
        navigateButton.setTitle("Go to settings", for: .normal)
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
        peripheralSession = PeripheralSession()
        peripheralSession.delegate = self
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
