import AVFoundation
import GDSCommon
import UIKit

// MARK: - Camera Error

public enum CameraError: LocalizedError {
    case cameraUnavailable
    case cameraPermissionDenied
    case cameraPermissionRestricted

    public var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera unavailable"
        case .cameraPermissionDenied:
            return "Camera permission denied"
        case .cameraPermissionRestricted:
            return "Camera permission restricted"
        }
    }
}

// MARK: - Camera Manager Protocol

public protocol CameraManagerProtocol {
    @MainActor
    func presentQRScanner(
        from viewController: UIViewController) async
}

// MARK: - Camera Manager Implementation

public class CameraManager: CameraManagerProtocol, @unchecked Sendable {

    private let cameraHardware: CameraHardwareProtocol

    fileprivate let viewModel = QRViewModel(
        title: "Scan QR Code",
        instructionText: "Position the QR code within the viewfinder to scan")

    public init(cameraHardware: CameraHardwareProtocol = CameraHardware()) {
        self.cameraHardware = cameraHardware
    }

    @MainActor
    public func presentQRScanner(
        from viewController: UIViewController
    ) async {
        do {
            guard isCameraAvailable() else {
                throw CameraError.cameraUnavailable
            }

            try await handleCameraPermission(
                for: viewController,
                viewModel: viewModel
            )
        } catch let cameraError as CameraError {
            handleCameraError(cameraError, from: viewController)
        } catch {
            logCameraError("Unexpected camera error: \(error.localizedDescription)")
        }
    }

    internal func isCameraAvailable() -> Bool {
        return cameraHardware.isCameraAvailable
    }

    @MainActor
    internal func handleCameraPermission(
        for viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async throws {
        let permissionStatus = cameraHardware.authorizationStatus

        switch permissionStatus {
        case .notDetermined:
            print("Camera permission not determined - requesting from user.")
            try await requestCameraPermission(
                for: viewController,
                viewModel: viewModel
            )
        case .authorized:
            print("Camera permission granted")
            presentScannerWithPermission(
                from: viewController,
                viewModel: viewModel
            )
        case .denied:
            throw CameraError.cameraPermissionDenied
        case .restricted:
            throw CameraError.cameraPermissionRestricted
        @unknown default:
            throw CameraError.cameraPermissionDenied
        }
    }

    @MainActor
    internal func requestCameraPermission(
        for viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async throws {
        let granted = await cameraHardware.requestAccess()

        if granted {
            print("Camera permission granted")
            presentScannerWithPermission(
                from: viewController,
                viewModel: viewModel
            )
        } else {
            throw CameraError.cameraPermissionDenied
        }
    }

    @MainActor
    internal func presentScannerWithPermission(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) {
        presentScanner(from: viewController, viewModel: viewModel)
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

    // MARK: - Error Handling

    @MainActor
    private func handleCameraError(_ error: CameraError, from viewController: UIViewController) {
        switch error {
        case .cameraUnavailable:
            logCameraError("Camera hardware unavailable")
            presentCameraErrorScreen(from: viewController)
        case .cameraPermissionDenied:
            logCameraError("User denied camera permissions")
            presentCameraErrorScreen(from: viewController)
        case .cameraPermissionRestricted:
            logCameraError("Camera permissions restricted")
            presentCameraErrorScreen(from: viewController)
        }
    }

    @MainActor
    private func presentCameraErrorScreen(from viewController: UIViewController) {
        let errorViewController = CameraPermissionErrorViewController()
        let navigationController = UINavigationController(rootViewController: errorViewController)
        navigationController.modalPresentationStyle = .formSheet
        viewController.present(navigationController, animated: true)
    }

    private func logCameraError(_ message: String) {
        print("Camera Error: \(message)")
    }
}

// MARK: - QR Scanning ViewModel

struct QRViewModel: QRScanningViewModel, Sendable {
    let title: String
    let instructionText: String

    func didScan(value: String, in _: UIView) async {
        print("QR Code scanned: \(value)")
        // TODO: DCMAW-16987 - QR code scanning and decoding logic to be called here
    }
}
