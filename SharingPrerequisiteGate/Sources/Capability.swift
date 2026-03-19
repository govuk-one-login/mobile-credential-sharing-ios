import AVFoundation
import CoreBluetooth

public enum Capability: CaseIterable, Sendable, Hashable, Equatable {
    case bluetooth
    case camera
}

public protocol MissingCapabilityReason: Sendable, Hashable, Equatable {}

public enum MissingBluetoothCapabilityReason: MissingCapabilityReason {
    case bluetoothAuthNotDetermined
    case bluetoothAuthRestricted
    case bluetoothAuthDenied
    case bluetoothStatePoweredOff
    case bluetoothStateUnknown
    case bluetoothStateUnsupported
    case bluetoothStateResetting
}

public enum MissingCameraCapabilityReason: MissingCapabilityReason {
    case cameraAuth
    case cameraState
}

public struct MissingCapability: Sendable {
    public let type: Capability
    public let reason: any MissingCapabilityReason

    public var description: String {
        switch reason {
        case let bluetooth as MissingBluetoothCapabilityReason:
            switch bluetooth {
            case .bluetoothAuthNotDetermined: return "Bluetooth authorization not determined"
            case .bluetoothAuthRestricted: return "Bluetooth authorization restricted"
            case .bluetoothAuthDenied: return "Bluetooth authorization denied"
            case .bluetoothStatePoweredOff: return "Bluetooth state powered off"
            case .bluetoothStateUnknown: return "Bluetooth state unknown"
            case .bluetoothStateUnsupported: return "Bluetooth state unsupported"
            case .bluetoothStateResetting: return "Bluetooth state resetting"
            }
        case let camera as MissingCameraCapabilityReason:
            switch camera {
            case .cameraAuth: return "Camera authorization"
            case .cameraState: return "Camera state"
            }
        default:
            return "Unknown capability issue"
        }
    }
    
    public init(type: Capability, reason: any MissingCapabilityReason) {
        self.type = type
        self.reason = reason
    }
}

extension MissingCapability: Equatable {
    public static func == (lhs: MissingCapability, rhs: MissingCapability) -> Bool {
        lhs.type == rhs.type && lhs.reason.hashValue == rhs.reason.hashValue
    }
}

extension MissingCapability: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(reason.hashValue)
    }
}
