import AVFoundation
import SharingCameraService

class MockCameraHardware: CameraCapabilityProviding {
    var authorizationStatus: AVAuthorizationStatus
    var isCameraAvailable: Bool
    var requestAccessCalled = false

    init(isCameraAvailable: Bool = true, authorizationStatus: AVAuthorizationStatus = .authorized) {
        self.isCameraAvailable = isCameraAvailable
        self.authorizationStatus = authorizationStatus
    }

    func requestAccess() async -> Bool {
        requestAccessCalled = true
        return authorizationStatus == .authorized
    }
}
