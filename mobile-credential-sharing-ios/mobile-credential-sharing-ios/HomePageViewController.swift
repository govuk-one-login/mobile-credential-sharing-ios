import HolderUI
import AVFoundation
import UIKit
import GDSCommon

class HomePageViewController: UIViewController {
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let navigateButton = UIButton(type: .system)
    var credentialPresenter: CredentialPresenter?
    let scanQRCodeButton = UIButton(type: .system)
    private let cameraManager: CameraManagerProtocol

    init(cameraManager: CameraManagerProtocol = CameraManager()) {
        self.cameraManager = cameraManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.cameraManager = CameraManager()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupTitle()
        setupNavigateButton()
        setupActivityIndicator()
        setupScanQRCodeButton()
    }

    private func setupTitle() {
        let titleLabel: UILabel = {
            let label = UILabel()
            label.text = "Welcome to GOV.UK Wallet Sharing"
            label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()

        view.addSubview(titleLabel)

        NSLayoutConstraint.activate(
            [
                titleLabel.centerXAnchor
                    .constraint(equalTo: view.centerXAnchor),
                titleLabel.centerYAnchor
                    .constraint(
                        equalTo: view.safeAreaLayoutGuide.topAnchor,
                    ),
                titleLabel.leadingAnchor
                    .constraint(equalTo: view.leadingAnchor, constant: 12),
                titleLabel.trailingAnchor
                    .constraint(equalTo: view.trailingAnchor, constant: -12)
            ]
        )
    }

    private func setupNavigateButton() {
        navigateButton.configuration = .bordered()
        navigateButton.configuration?.baseBackgroundColor = .systemGreen
        navigateButton.configuration?.baseForegroundColor = .white
        navigateButton.configuration?.contentInsets = .init(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )

        navigateButton.setTitle("Display QR code", for: .normal)
        navigateButton.titleLabel?.font = UIFont
            .preferredFont(forTextStyle: .headline)
        navigateButton.translatesAutoresizingMaskIntoConstraints = false
        navigateButton
            .addTarget(
                self,
                action: #selector(navigateButtonTapped),
                for: .touchUpInside
            )

        view.addSubview(navigateButton)

        NSLayoutConstraint.activate([
            navigateButton.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            navigateButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor
                .constraint(equalTo: navigateButton.topAnchor, constant: -62)
        ])
    }

    @objc private func navigateButtonTapped() {
        activityIndicator.startAnimating()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.navigateToQRCodeView()
        }
    }

    func navigateToQRCodeView() {
        credentialPresenter = CredentialPresenter()
        credentialPresenter?.presentCredential(Data(), over: self)
        activityIndicator.stopAnimating()
    }

    // MARK: - QR Scanning

    private func setupScanQRCodeButton() {
        scanQRCodeButton.configuration = .bordered()
        scanQRCodeButton.configuration?.baseBackgroundColor = .systemBlue
        scanQRCodeButton.configuration?.baseForegroundColor = .white
        scanQRCodeButton.configuration?.contentInsets = .init(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
        scanQRCodeButton.setTitle("Scan QR Code", for: .normal)
        scanQRCodeButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.addTarget(
            self,
            action: #selector(scanQRCodeButtonTapped),
            for: .touchUpInside
        )
        view.addSubview(scanQRCodeButton)
        NSLayoutConstraint.activate([
            scanQRCodeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanQRCodeButton.topAnchor.constraint(equalTo: navigateButton.bottomAnchor, constant: 24)
        ])
    }

    @objc private func scanQRCodeButtonTapped() {
        Task {
            let viewModel = QRViewModel(
                title: "Scan QR Code",
                instructionText: "Position the QR code within the viewfinder to scan"
            )

            let success = await cameraManager.presentQRScanner(
                from: self,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - QR Scanning ViewModel

private struct QRViewModel: QRScanningViewModel {
    let title: String
    let instructionText: String

    func didScan(value: String, in view: UIView) async {
        print("QR Code scanned: \(value)")
        // TODO: DCMAW-16987 - QR code scanning and decoding logic here
    }
}
