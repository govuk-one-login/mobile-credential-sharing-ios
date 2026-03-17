import AVFoundation
import CoreBluetooth

public enum Capability: CaseIterable, Sendable, Hashable, Equatable {
    case bluetooth
    case camera
}

public enum MissingCapabilityReason: Sendable, Hashable, Equatable {
    case bluetoothAuthNotDetermined
    case bluetoothAuthRestricted
    case bluetoothAuthDenied
    case bluetoothStatePoweredOff
    case bluetoothStateUnknown
    case bluetoothStateUnsupported
    case bluetoothStateResetting
    case cameraAuth
    case cameraState
}

public struct MissingCapability: Sendable, Hashable, Equatable {
    public let type: Capability
    public let reason: MissingCapabilityReason

    public var description: String {
        switch reason {
        case .bluetoothAuthNotDetermined: return "Bluetooth authorization not determined"
        case .bluetoothAuthRestricted: return "Bluetooth authorization restricted"
        case .bluetoothAuthDenied: return "Bluetooth authorization denied"
        case .bluetoothStatePoweredOff: return "Bluetooth state powered off"
        case .bluetoothStateUnknown: return "Bluetooth state unknown"
        case .bluetoothStateUnsupported: return "Bluetooth state unsupported"
        case .bluetoothStateResetting: return "Bluetooth state resetting"
        case .cameraAuth: return "Camera authorization"
        case .cameraState: return "Camera state"
        }
    }
    
    public init(type: Capability, reason: MissingCapabilityReason) {
        self.type = type
        self.reason = reason
    }
}
