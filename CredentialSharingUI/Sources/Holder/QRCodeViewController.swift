import SharingBluetoothTransport
import UIKit

protocol QRCodeViewControllerDelegate: AnyObject {
    func didTapCancel()
    func didTapNavigateToSettings()
    func didFailToGenerateQRCode()
}

/// Outcome of rendering the QR code. Callers must only navigate to / keep the
/// QR screen presented on `.success`; on `.failure` the delegate has already
/// been notified and the session is being torn down.
enum QRCodeRenderResult {
    case success
    case failure
}

class QRCodeViewController: UIViewController {
    weak var delegate: QRCodeViewControllerDelegate?

    var engagementPresentation: EngagementPresentation
    var activityIndicator = UIActivityIndicatorView(style: .large)
    var qrCodeImageView = UIImageView()
    private var qrPayload: String? {
        engagementPresentation.qrPayload
    }
    private(set) var qrCode: UIImage?

    init(engagementPresentation: EngagementPresentation) {
        self.engagementPresentation = engagementPresentation
        super.init(nibName: nil, bundle: nil)
        self.presentationController?.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "QR Code"
        navigationController?.navigationBar.titleTextAttributes = [.font: UIFont.systemFont(
            ofSize: 24,
            weight: .bold
        )]
        navigationItem.hidesBackButton = true
        view.backgroundColor = .systemBackground
        
        setupActivityIndicator()
        activityIndicator.startAnimating()
    }
    
    /// Generates the QR image from the current payload. On failure the error is surfaced
    /// to the delegate - without a QR code the engagement cannot proceed.
    private func regenerateQRCode() -> QRCodeRenderResult {
        guard let qrPayload else {
            // Nil payload is a valid "hidden" presentation, not a failure.
            qrCode = nil
            return .success
        }
        do {
            qrCode = try QRGenerator(path: qrPayload).generateQRCode()
            return .success
        } catch {
            qrCode = nil
            delegate?.didFailToGenerateQRCode()
            return .failure
        }
    }
    
    func showSettingsButton() {
        activityIndicator.stopAnimating()
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
    
    @discardableResult
    func showQRCode() -> QRCodeRenderResult {
        guard regenerateQRCode() == .success else {
            return .failure
        }
        activityIndicator.stopAnimating()
        qrCodeImageView.image = qrCode
        view.addSubview(qrCodeImageView)
        
        qrCodeImageView.translatesAutoresizingMaskIntoConstraints = false
        qrCodeImageView.contentMode = .scaleAspectFit
        
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate(
            [
                qrCodeImageView.centerYAnchor
                    .constraint(equalTo: safeArea.centerYAnchor),
                qrCodeImageView.centerXAnchor
                    .constraint(equalTo: safeArea.centerXAnchor),
                qrCodeImageView.widthAnchor
                    .constraint(
                        lessThanOrEqualTo: safeArea.widthAnchor,
                        multiplier: 0.75
                    ),
                qrCodeImageView.heightAnchor
                    .constraint(
                        lessThanOrEqualTo: safeArea.heightAnchor,
                        multiplier: 0.75
                    ),
                qrCodeImageView.widthAnchor
                    .constraint(equalTo: qrCodeImageView.heightAnchor)
            ]
        )
        return .success
    }
    
    /// Swaps the displayed QR code in place without pushing a new view controller.
    /// Used when the engagement QR refreshes while the Holder is still presenting.
    func update(engagementPresentation: EngagementPresentation) {
        self.engagementPresentation = engagementPresentation
        if view.subviews.contains(qrCodeImageView) {
            guard regenerateQRCode() == .success else { return }
            if qrCode == nil {
                // Hidden presentation (nil payload): drop the QR and show the spinner
                // while the session continues advertising / refreshing.
                qrCodeImageView.image = nil
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
                qrCodeImageView.image = qrCode
            }
        } else {
            showQRCode()
        }
    }
}

// MARK: - Presentation Controller Delegate
extension QRCodeViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if view.subviews.contains(qrCodeImageView) {
            delegate?.didTapCancel()
        }
    }
}
