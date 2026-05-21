import AVFoundation

// MARK: - Camera Hardware Protocol

public protocol CameraCapabilityProviding {
    var authorizationStatus: AVAuthorizationStatus { get }
    var isCameraAvailable: Bool { get }
    func requestAccess(completionHandler: @escaping (Bool) -> Void)
}

// MARK: - Default Camera Hardware Implementation

public struct CameraCapabilityProvider: CameraCapabilityProviding {
    public var authorizationStatus: AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }

    public var isCameraAvailable: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else {
            return false
        }
        return !device.isSuspended
    }

    public init() {
        /// Empty initializer - no setup required, init must exist for class to be public facing
    }

    public func requestAccess(completionHandler: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completionHandler)
    }
}
