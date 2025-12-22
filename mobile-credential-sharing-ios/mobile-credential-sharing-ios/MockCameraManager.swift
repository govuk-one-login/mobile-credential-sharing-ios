import UIKit
import GDSCommon

// MARK: - Mock Camera Manager

public class MockCameraManager: CameraManagerProtocol {
    public var shouldReturnSuccess = true
    public private(set) var presentQRScannerCallCount = 0
    public private(set) var lastPresentedFromViewController: UIViewController?

    // must be two string values - can't make comparisons in unit tests with protocol QRScanningViewModel
    public private(set) var lastViewModelTitle: String?
    public private(set) var lastViewModelInstructionText: String?

    public init() {}

    public func presentQRScanner(
        from viewController: UIViewController,
        viewModel: QRScanningViewModel
    ) async -> Bool {
        presentQRScannerCallCount += 1
        lastPresentedFromViewController = viewController
        lastViewModelTitle = viewModel.title
        lastViewModelInstructionText = viewModel.instructionText

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