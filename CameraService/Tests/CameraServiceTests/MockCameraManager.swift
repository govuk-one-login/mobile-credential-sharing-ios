import CameraService
import GDSCommon
import UIKit

// MARK: - MockCameraManager
// SonarQube: Exclude from coverage - test infrastructure only

@preconcurrency
final class MockCameraManager: CameraManagerProtocol, @unchecked Sendable {
    var shouldThrowError: CameraError?
    private(set) var presentQRScannerCallCount = 0
    private(set) var lastPresentedFromViewController: UIViewController?

    // must be two string values - can't make comparisons in unit tests with protocol QRScanningViewModel
    private(set) var lastViewModelTitle: String?
    private(set) var lastViewModelInstructionText: String?

    @MainActor
    func presentQRScanner(
        from viewController: UIViewController) async throws {
        presentQRScannerCallCount += 1
        lastPresentedFromViewController = viewController

        // Access main actor properties directly since we're MainActor-isolated
        let mockViewModel = MockQRScanningViewModel()
        lastViewModelTitle = mockViewModel.title
        lastViewModelInstructionText = mockViewModel.instructionText

        if let error = shouldThrowError {
            throw error
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
