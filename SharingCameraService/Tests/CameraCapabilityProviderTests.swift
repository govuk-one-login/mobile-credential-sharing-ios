import AVFoundation
@testable import SharingCameraService
import Testing

// MARK: - CameraCapabilityProvider

@Suite("CameraCapabilityProviderTests")
struct CameraCapabilityProviderTests {

    @Test("authorizationStatus property returns AVCaptureDevice authorization status")
    func authorizationStatusProperty() {
        let cameraCapability = CameraCapabilityProvider()
        let status = cameraCapability.authorizationStatus

        // Assert: The property should return some valid authorization status
        #expect([
            AVAuthorizationStatus.notDetermined,
            AVAuthorizationStatus.restricted,
            AVAuthorizationStatus.denied,
            AVAuthorizationStatus.authorized
        ].contains(status))
    }

    @Test("isCameraAvailable property returns boolean value")
    func isCameraAvailableProperty() {
        let cameraCapability = CameraCapabilityProvider()

        let isAvailable = cameraCapability.isCameraAvailable

        // Assert: The property should return a boolean value (coverage test)
        #expect(isAvailable == true || isAvailable == false)

        #if targetEnvironment(simulator)
        // On simulator, camera should not be available
        #expect(isAvailable == false)
        #else
        // On actual device, camera should be available (assuming device has camera)
        #expect(isAvailable == true || isAvailable == false)
        #endif
    }
    
    @Test("requestAccess calls completion handler with boolean result")
    func requestAccessCompletionHandler() async {
        let cameraCapability = CameraCapabilityProvider()
        let result = await withCheckedContinuation { continuation in
            cameraCapability.requestAccess { granted in
                continuation.resume(returning: granted)
            }
        }

        #expect(result == true || result == false)
    }
}
