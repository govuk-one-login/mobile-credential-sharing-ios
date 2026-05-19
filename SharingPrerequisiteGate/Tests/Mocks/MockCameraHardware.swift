import AVFoundation
import SharingCameraService

class MockCameraHardware: CameraHardwareProtocol {
    var authorizationStatus: AVAuthorizationStatus
    var isCameraAvailable: Bool

    init(isCameraAvailable: Bool = true, authorizationStatus: AVAuthorizationStatus = .authorized) {
        self.isCameraAvailable = isCameraAvailable
        self.authorizationStatus = authorizationStatus
    }

    func requestAccess() async -> Bool {
        return authorizationStatus == .authorized
    }
}
