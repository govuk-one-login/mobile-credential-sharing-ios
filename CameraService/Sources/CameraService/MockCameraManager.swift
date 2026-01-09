import GDSCommon
import UIKit

// MARK: - Mock Camera Manager

@preconcurrency
public final class MockCameraManager: CameraManagerProtocol, @unchecked Sendable {
    public var shouldReturnSuccess = true
    public private(set) var presentQRScannerCallCount = 0
    public private(set) var lastPresentedFromViewController: UIViewController?

    // must be two string values - can't make comparisons in unit tests with protocol QRScanningViewModel
    public private(set) var lastViewModelTitle: String?
    public private(set) var lastViewModelInstructionText: String?

    public init() {}

    nonisolated public func presentQRScanner(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool {
        presentQRScannerCallCount += 1
        lastPresentedFromViewController = viewController

        // Access main actor properties safely using wrapper
        let sendableViewModel = UnsafeSendableWrapper(viewModel)
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

private struct UnsafeSendableWrapper<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}
