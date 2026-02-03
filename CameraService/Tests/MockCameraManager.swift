import CameraService
import GDSCommon
import UIKit

// MARK: - MockCameraManager
// SonarQube: Exclude from coverage - test infrastructure only

final class MockCameraManager: CameraManagerProtocol {
    var shouldThrowError: CameraError?
    private(set) var presentQRScannerCallCount = 0
    private(set) var lastPresentedFromViewController: UIViewController?

    // must be two string values - can't make comparisons in unit tests with protocol QRScanningViewModel
    private(set) var lastViewModelTitle: String?
    private(set) var lastViewModelInstructionText: String?

    func presentQRScanner(
        from viewController: UIViewController) {
        presentQRScannerCallCount += 1
        lastPresentedFromViewController = viewController

        // Access main actor properties directly since we're MainActor-isolated
        let mockViewModel = MockQRScanningViewModel()
        lastViewModelTitle = mockViewModel.title
        lastViewModelInstructionText = mockViewModel.instructionText

        // For testing, we can still simulate errors by setting shouldThrowError
        // but the method signature doesn't throw - errors are handled internally
        if shouldThrowError != nil {
            // In real implementation, this would show error screen
            print("Mock: Would show error screen for \(shouldThrowError ?? .cameraUnavailable)")
        }
    }

    func reset() {
        presentQRScannerCallCount = 0
        lastPresentedFromViewController = nil
        lastViewModelTitle = nil
        lastViewModelInstructionText = nil
        shouldThrowError = nil
    }
}

// MARK: - Sendable Wrapper for Mock Testing

private struct MockSendableWrapper<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Mock QRScanningViewModel

@MainActor
class MockQRScanningViewModel: QRScanningViewModel {
    let title = "Test Scanner"
    let instructionText = "Test instructions"

    func didScan(value: String, in view: UIView) async {
        // Does nothing in tests
    }
}
