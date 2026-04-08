import Foundation

public enum Prerequisite: CaseIterable, Sendable, Hashable, Equatable {
    case bluetooth
    case camera
}

public enum MissingPrerequisite: Equatable, CustomStringConvertible {
    public enum Bluetooth: Equatable {
        case authorizationNotDetermined
        case authorizationDenied
        case authorizationRestricted
        case statePoweredOff
        case stateUnsupported
        case stateUnauthorized
        case stateResetting
        case stateUnknown
    }
    
    public enum Camera: Equatable {
        case authorizationNotDetermined
        case authorizationDenied
        case authorizationRestricted
        case stateUnsupported
    }
    
    case bluetooth(Bluetooth)
    case camera(Camera)
    
    public var prerequisite: Prerequisite {
        switch self {
        case .bluetooth: return .bluetooth
        case .camera: return .camera
        }
    }
    
    public var isRecoverable: Bool {
        switch self {
        case .bluetooth(.authorizationNotDetermined), 
                .bluetooth(.stateUnknown), 
                .bluetooth(.statePoweredOff):
            return true
        case .camera(.authorizationNotDetermined):
            return true
        default:
            // Denied, Restricted, and Unsupported are terminal for the automated flow
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .bluetooth(let bluetooth):
            return switch bluetooth {
            case .authorizationNotDetermined:
                "Bluetooth authorization not determined"
            case .authorizationDenied:
                "Bluetooth authorization denied"
            case .authorizationRestricted:
                "Bluetooth authorization restricted"
            case .statePoweredOff:
                "Bluetooth state powered off"
            case .stateUnsupported:
                "Bluetooth state unsupported"
            case .stateUnauthorized:
                "Bluetooth state unauthorized"
            case .stateResetting:
                "Bluetooth state resetting"
            case .stateUnknown:
                "Bluetooth state unknown"
            }
        case .camera(let camera):
            return switch camera {
            case .authorizationNotDetermined:
                "Camera authorization not determined"
            case .authorizationDenied:
                "Camera authorization denied"
            case .authorizationRestricted:
                "Camera authorization restricted"
            case .stateUnsupported:
                "Camera state unsupported"
            }
        }
    }
}
