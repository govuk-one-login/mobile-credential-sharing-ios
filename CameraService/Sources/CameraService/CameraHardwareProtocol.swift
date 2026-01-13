import AVFoundation

// MARK: - Camera Hardware Protocol

public protocol CameraHardwareProtocol {
    var authorizationStatus: AVAuthorizationStatus { get }
    var isDeviceAvailable: Bool { get }
    func requestAccess() async -> Bool
}

// MARK: - Default Camera Hardware Implementation

public struct CameraHardware: CameraHardwareProtocol {
    public var authorizationStatus: AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }

    public var isDeviceAvailable: Bool {
        return AVCaptureDevice.default(for: .video) != nil
    }

    public func requestAccess() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    public init() {}
}
