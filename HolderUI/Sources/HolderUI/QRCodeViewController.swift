import Bluetooth
import Holder
internal import SwiftCBOR
import UIKit

public class QRCodeViewController: UIViewController {
    var delegate: QRCodeViewControllerDelegate?
    var activityIndicator = UIActivityIndicatorView(style: .large)
    var qrCodeImageView = UIImageView()
    let qrCode: UIImage?
    
    public init(qrCode: UIImage? = nil) {
        self.qrCode = qrCode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        title = "QR Code"
        navigationController?.navigationBar.titleTextAttributes = [.font: UIFont.systemFont(
            ofSize: 24,
            weight: .bold
        )]
        view.backgroundColor = .systemBackground
        
        setupActivityIndicator()
        activityIndicator.startAnimating()
    }
    
    public func showSettingsButton() {
        setupNavigateToSettingsButton()
    }
    
    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor
                .constraint(equalTo: view.centerYAnchor)
        ])
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
        delegate?.didTapNavigateToSettings()
    }
    
    public func showQRCode() {
        qrCodeImageView.image = qrCode
        view.addSubview(qrCodeImageView)
        
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

public protocol QRCodeViewControllerDelegate: AnyObject {
    func didTapNavigateToSettings()
}
