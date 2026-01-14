import AVFoundation

// MARK: - Camera Hardware Protocol

public protocol CameraHardwareProtocol {
    var authorizationStatus: AVAuthorizationStatus { get }
    var isCameraAvailable: Bool { get }
    func requestAccess() async -> Bool
}

// MARK: - Default Camera Hardware Implementation

public struct CameraHardware: CameraHardwareProtocol {
    public var authorizationStatus: AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }

    public var isCameraAvailable: Bool {
        guard let device = AVCaptureDevice.default(for: .video) else {
            return false
        }
        return !device.isSuspended
    }

    /// Empty initializer - no stored properties require initialization
    /// All properties are computed properties that access AVCaptureDevice directly
    public init() {}

    public func requestAccess() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video)
    }
}
