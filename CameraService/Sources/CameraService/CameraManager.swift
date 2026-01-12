import AVFoundation
import GDSCommon
import UIKit

// MARK: - Camera Manager Protocol

public protocol CameraManagerProtocol {
    func presentQRScanner(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool
}

// MARK: - Camera Manager Implementation

public class CameraManager: CameraManagerProtocol {

    /// CameraManager initializer
    /// Intentionally empty as no initial configuration is required
    public init() {}

    public func presentQRScanner(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
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

    private func isCameraAvailable() -> Bool {
        return AVCaptureDevice.default(for: .video) != nil
    }

    private func handleCameraPermission(
        for viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)

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

    private func requestCameraPermission(
        for viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)

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
    private func presentScannerWithPermission(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) -> Bool {
        presentScanner(from: viewController, viewModel: viewModel)
        return true
    }

    @MainActor
    private func presentScanner(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) {
        let scannerVC = ScanningViewController<AVCaptureSession>(viewModel: viewModel)
        scannerVC.modalPresentationStyle = .fullScreen
        viewController.present(scannerVC, animated: true)
    }
}
