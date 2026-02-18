import AVFoundation
import CoreBluetooth

public enum Capability: CaseIterable, Sendable, Hashable, Equatable {
    
    public enum CapabilityDisallowedReason: String, Sendable {
        case bluetoothAuthNotDetermined = "Bluetooth authorization not determined"
        case bluetoothAuthRestricted = "Bluetooth authorization restricted"
        case bluetoothAuthDenied = "Bluetooth authorization denied"
        case bluetoothStatePoweredOff = "Bluetooth state powered off"
        case bluetoothStateUnknown = "Bluetooth state unknown"
        case bluetoothStateUnsupported = "Bluetooth state unsupported"
        case bluetoothStateResetting = "Bluetooth state resetting"
        case cameraAuth = "Camera authorization"
        case cameraState = "Camera state"
    }
    
    case bluetooth(CapabilityDisallowedReason? = nil)
    case camera(CapabilityDisallowedReason? = nil)
    
    public static let allCases: [Capability] = [.bluetooth(), .camera()]
   
    var isAllowed: Bool {
        switch self {
        case .bluetooth:
            return CBManager.authorization == .allowedAlways
        case .camera:
            return AVCaptureDevice.default(for: .video) != nil &&
            AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
    }
    
    public var rawValue: String {
        switch self {
        case .bluetooth(let reason):
            return reason?.rawValue ?? ""
        case .camera(let reason):
            return reason?.rawValue ?? ""
        }
    }
}
