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
    private weak var scannerViewController: UIViewController?
    private weak var originalPresentingViewController: UIViewController?

    fileprivate var viewModel: QRViewModel {
        QRViewModel(
            title: "Scan QR Code",
            instructionText: "Position the QR code within the viewfinder to scan",
            dismissScanner: { @MainActor in
                self.dismissScanner()
            },
            presentInvalidQRError: { @MainActor in
                self.presentInvalidQRErrorScreen()
            }
        )
    }

    public init(cameraHardware: CameraHardwareProtocol = CameraHardware()) {
        self.cameraHardware = cameraHardware
    }

    @MainActor
    public func presentQRScanner(
        from viewController: UIViewController
    ) async {
        self.originalPresentingViewController = viewController

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
        self.scannerViewController = scannerVC // Retain reference for dismissal
        viewController.present(scannerVC, animated: true)
    }

    @MainActor
    internal func dismissScanner() {
        scannerViewController?.dismiss(animated: true)
        scannerViewController = nil // Clear reference after dismissal
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

    @MainActor
    private func presentInvalidQRErrorScreen() {
        guard let presentingVC = originalPresentingViewController else {
            print("Warning: No view controller found to show invalid QR error")
            return
        }

        let errorViewController = InvalidQRErrorViewController()
        let navigationController = UINavigationController(rootViewController: errorViewController)
        navigationController.modalPresentationStyle = .formSheet
        presentingVC.present(navigationController, animated: true)
    }

    private func logCameraError(_ message: String) {
        print("Camera Error: \(message)")
    }
}
