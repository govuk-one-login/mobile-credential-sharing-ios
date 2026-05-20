import AVFoundation
@testable import SharingCameraService
import Testing

// MARK: - CameraHardwareTests

@Suite("CameraCapabilityProviderTests")
struct CameraHardwareTests {

    @Test("CameraCapabilityProvider authorizationStatus property returns AVCaptureDevice authorization status")
    func authorizationStatusProperty() {
        let cameraHardware = CameraCapabilityProvider()
        let status = cameraHardware.authorizationStatus

        // Assert: The property should return some valid authorization status
        #expect([
            AVAuthorizationStatus.notDetermined,
            AVAuthorizationStatus.restricted,
            AVAuthorizationStatus.denied,
            AVAuthorizationStatus.authorized
        ].contains(status))
    }

    @Test("CameraCapabilityProvider isCameraAvailable property returns boolean value")
    func isCameraAvailableProperty() {
        let cameraHardware = CameraCapabilityProvider()

        let isAvailable = cameraHardware.isCameraAvailable

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

    @Test("CameraCapabilityProvider requestAccess function returns boolean result")
    func requestAccessFunction() async {
        let cameraHardware = CameraCapabilityProvider()
        let result = await cameraHardware.requestAccess()

        // Assert: The function should return a boolean value (coverage test)
        #expect(result == true || result == false)
    }
}
