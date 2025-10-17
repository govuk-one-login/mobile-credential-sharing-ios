import UIKit
import Holder

class QRCodeViewController: UIViewController {
    
    var qrCodeImageView = UIImageView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "QR Code"
        navigationController?.navigationBar.titleTextAttributes = [.font: UIFont.systemFont(
            ofSize: 24,
            weight: .bold
        )]
        
        view.backgroundColor = .systemBackground
        
        do {
            try setupQRCode()
        } catch {
            fatalError("Unable to create QR code")
        }
    }
    
    private func setupQRCode() throws {
        do {
            let qrCode: UIImage = try QRGenerator(url: "https://www.gov.uk/").generateQRCode()
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
