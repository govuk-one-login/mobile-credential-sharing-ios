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

    fileprivate var viewModel: QRViewModel {
        QRViewModel(
            title: "Scan QR Code",
            instructionText: "Position the QR code within the viewfinder to scan",
            dismissScanner: { @MainActor in
                self.dismissScanner()
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

    private func logCameraError(_ message: String) {
        print("Camera Error: \(message)")
    }
}

// MARK: - QR Scanning ViewModel

struct QRViewModel: QRScanningViewModel, Sendable {
    let title: String
    let instructionText: String
    let dismissScanner: @Sendable @MainActor () async -> Void

    func didScan(value: String, in view: UIView) async {
        if let url = extractURL(from: value), isWebsiteURL(url) {
            // Dismiss scanner to prevent multiple scans
            await dismissScanner()
            await handleURLScanned(url: url)
        } else {
            logNonURLScan(value: value)
        }
    }

    internal func extractURL(from value: String) -> URL? {
        // Create URL directly from the value
        if let url = URL(string: value), url.scheme != nil {
            return url
        }

        // If that doesn't work, then find URL within the text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: value.utf16.count)
        if let match = detector?.firstMatch(in: value, options: [], range: range),
           let url = match.url {
            return url
        }
        return nil
    }

    private func isWebsiteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    @MainActor
    private func handleURLScanned(url: URL) async {
        if let host = url.host?.lowercased(), host.contains("gov.uk") {
            print("QR Code scanned - gov.uk URL found: \(url.absoluteString)")
        } else {
            print("QR Code scanned - URL found: \(url.absoluteString)")
        }

        // Open URL in default browser
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if success {
                    print("Successfully opened QR URL in browser: \(url.absoluteString)")
                } else {
                    print("Failed to open QR URL in browser: \(url.absoluteString)")
                }
            }
        } else {
            print("Cannot open QR URL: \(url.absoluteString)")
        }
    }

    private func logNonURLScan(value: String) {
        if let url = extractURL(from: value) {
            print("QR Code scanned - non-website URL found: \(url.absoluteString). Content: \(value)")
        } else {
            print("QR Code scanned - no URL found. Content: \(value)")
        }
    }
}
