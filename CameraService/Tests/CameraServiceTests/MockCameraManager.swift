import CameraService
import GDSCommon
import UIKit

// MARK: - MockCameraManager
// SonarQube: Exclude from coverage - test infrastructure only

@preconcurrency
public final class MockCameraManager: CameraManagerProtocol, @unchecked Sendable {
    public var shouldReturnSuccess = true
    public private(set) var presentQRScannerCallCount = 0
    public private(set) var lastPresentedFromViewController: UIViewController?

    // must be two string values - can't make comparisons in unit tests with protocol QRScanningViewModel
    public private(set) var lastViewModelTitle: String?
    public private(set) var lastViewModelInstructionText: String?

    /// MockCameraManager initializer
    /// Intentionally empty as no initial configuration is required
    public init() {}

    nonisolated public func presentQRScanner(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool {
        presentQRScannerCallCount += 1
        lastPresentedFromViewController = viewController

        // Access main actor properties safely using wrapper
        let sendableViewModel = MockSendableWrapper(viewModel)
        let title = await MainActor.run { sendableViewModel.value.title }
        let instructionText = await MainActor.run { sendableViewModel.value.instructionText }

        lastViewModelTitle = title
        lastViewModelInstructionText = instructionText

        return shouldReturnSuccess
    }

    public func reset() {
        presentQRScannerCallCount = 0
        lastPresentedFromViewController = nil
        lastViewModelTitle = nil
        lastViewModelInstructionText = nil
        shouldReturnSuccess = true
    }
}

// MARK: - Sendable Wrapper for Mock Testing

private struct MockSendableWrapper<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}
