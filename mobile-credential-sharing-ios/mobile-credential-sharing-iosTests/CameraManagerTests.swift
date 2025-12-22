@testable import mobile_credential_sharing_ios
import Testing
internal import UIKit
import GDSCommon

@MainActor
@Suite("CameraManagerTests")
struct CameraManagerTests {

    // MARK: - Mock CameraManager Tests (AC scenarios)
    let mock: MockCameraManager
    let viewController: UIViewController
    private let viewModel: MockQRScanningViewModel

    init() {
        mock = MockCameraManager()
        viewController = UIViewController()
        viewModel = MockQRScanningViewModel()
    }

    @Test("AC1: First time user - Permission granted scenario")
    func firstTimeUserPermissionGranted() async {

        mock.shouldReturnSuccess = true

        let result = await mock.presentQRScanner(from: viewController, viewModel: viewModel)

        #expect(result == true)
        #expect(mock.presentQRScannerCallCount == 1)
        #expect(mock.lastPresentedFromViewController === viewController)
        #expect(mock.lastViewModelTitle == "Test Scanner") 
        #expect(mock.lastViewModelInstructionText == "Test instructions")
    }

    @Test("AC2: Returning user - Permission already granted")
    func returningUserPermissionAlreadyGranted() async {

        mock.shouldReturnSuccess = true

        let result = await mock.presentQRScanner(from: viewController, viewModel: viewModel)

        #expect(result == true)
        #expect(mock.presentQRScannerCallCount == 1)
    }

    @Test("Permission denied scenario")
    func permissionDenied() async {

        mock.shouldReturnSuccess = false

        let result = await mock.presentQRScanner(from: viewController, viewModel: viewModel)

        #expect(result == false)
        #expect(mock.presentQRScannerCallCount == 1)
    }

    @Test("MockCameraManager reset functionality")
    func mockCameraManagerReset() async {

        // Make a call
        _ = await mock.presentQRScanner(from: viewController, viewModel: viewModel)

        // Verify call was made
        #expect(mock.presentQRScannerCallCount == 1)

        // Reset
        mock.reset()
        #expect(mock.presentQRScannerCallCount == 0)
        #expect(mock.lastPresentedFromViewController == nil)
        #expect(mock.lastViewModelTitle == nil)
        #expect(mock.lastViewModelInstructionText == nil)
        #expect(mock.shouldReturnSuccess == true)
    }
}

// MARK: - Test Helper

private class MockQRScanningViewModel: QRScanningViewModel {
    let title = "Test Scanner"
    let instructionText = "Test instructions"

    func didScan(value: String, in view: UIView) async {
        // No-op for tests
    }
}
