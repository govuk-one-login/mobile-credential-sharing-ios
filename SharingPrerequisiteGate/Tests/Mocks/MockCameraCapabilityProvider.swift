import AVFoundation
import SharingCameraService

class MockCameraCapabilityProvider: CameraCapabilityProviding {
    var authorizationStatus: AVAuthorizationStatus
    var isCameraAvailable: Bool
    var requestAccessCalled = false

    init(isCameraAvailable: Bool = true, authorizationStatus: AVAuthorizationStatus = .authorized) {
        self.isCameraAvailable = isCameraAvailable
        self.authorizationStatus = authorizationStatus
    }

    func requestAccess(completionHandler: @escaping (Bool) -> Void) {
        requestAccessCalled = true
        completionHandler(authorizationStatus == .authorized)
    }
}
