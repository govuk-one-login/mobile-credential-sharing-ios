import AVFoundation
import GDSCommon
import UIKit

// MARK: - Camera Manager Protocol

public protocol CameraManagerProtocol {
    func presentQRScanner(
        from viewController: UIViewController) async -> Bool
}

// MARK: - Camera Manager Implementation

public class CameraManager: CameraManagerProtocol {

    private let cameraHardware: CameraHardwareProtocol

    fileprivate let viewModel = QRViewModel(
        title: "Scan QR Code",
        instructionText: "Position the QR code within the viewfinder to scan")

    public init(cameraHardware: CameraHardwareProtocol = CameraHardware()) {
        self.cameraHardware = cameraHardware
    }

    public func presentQRScanner(
        from viewController: UIViewController
    ) async -> Bool {
        guard isCameraAvailable() else {
            print("Camera unavailable")
            return false
        }

        return await handleCameraPermission(
            for: viewController,
            viewModel: viewModel
        )
    }

    internal func isCameraAvailable() -> Bool {
        return cameraHardware.isDeviceAvailable
    }

    internal func handleCameraPermission(
        for viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool {
        let permissionStatus = cameraHardware.authorizationStatus

        switch permissionStatus {
        case .notDetermined:
            print("Camera permission not determined - requesting from user.")
            return await requestCameraPermission(
                for: viewController,
                viewModel: viewModel
            )
        case .authorized:
            print("Camera permission granted")
            return await presentScannerWithPermission(
                from: viewController,
                viewModel: viewModel
            )
        case .denied, .restricted:
            return false // TODO: DCMAW-16986 - denial scenarios
        @unknown default:
            return false
        }
    }

    internal func requestCameraPermission(
        for viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool {
        let granted = await cameraHardware.requestAccess()

        if granted {
            print("Camera permission granted")
            return await presentScannerWithPermission(
                from: viewController,
                viewModel: viewModel
            )
        } else {
            return false // TODO: DCMAW-16986 - denial scenarios
        }
    }

    @MainActor
    internal func presentScannerWithPermission(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) -> Bool {
        presentScanner(from: viewController, viewModel: viewModel)
        return true
    }

    @MainActor
    internal func presentScanner(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) {
        let scannerVC = ScanningViewController<AVCaptureSession>(viewModel: viewModel)
        scannerVC.modalPresentationStyle = .fullScreen
        viewController.present(scannerVC, animated: true)
    }
}

// MARK: - QR Scanning ViewModel

struct QRViewModel: QRScanningViewModel {
    let title: String
    let instructionText: String

    func didScan(value: String, in _: UIView) async {
        print("QR Code scanned: \(value)")
        // TODO: DCMAW-16987 - QR code scanning and decoding logic here
    }
}
