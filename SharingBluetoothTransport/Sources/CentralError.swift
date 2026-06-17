import CoreBluetooth
import Foundation

public enum CentralError: Equatable, LocalizedError {
    case notPoweredOn(CBManagerState)
    case permissionsNotGranted(CBManagerAuthorization)
    case serviceUUIDNotSet
    
    case connectError
    case discoverServicesError(String)
    case discoverCharacteristicsError(String)
    
    case gattServiceMissing
    case transportError(String)
    
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .notPoweredOn:
            return "Bluetooth is not ready. Current state: \(poweredOnState ?? "Unknown")."
        case .permissionsNotGranted:
            return "App does not have the required Bluetooth permissions. Current state: \(permissionState ?? "Unknown")."
        case .serviceUUIDNotSet:
            return "serviceUUID not set on session."
        case .connectError:
            return "Failed to connect to peripheral."
        case .discoverServicesError(let description):
            return "Failed to discover services: \(description)."
        case .discoverCharacteristicsError(let description):
            return "Failed to discover characteristics: \(description)."
        case .gattServiceMissing:
            return "Failed to find stored GATT Service."
        case .transportError(let description):
            return "Failed to perform transport operation: \(description)."
        case .unknown:
            return "An unknown error has occurred."
        }
    }
    
    var poweredOnState: String? {
        switch self {
        case .notPoweredOn(let state):
            switch state {
            case .resetting:
                return "Resetting"
            case .unauthorized:
                return "Unauthorized"
            case .unknown:
                return "Unknown"
            case .unsupported:
                return "Unsupported"
            case .poweredOff:
                return "Powered off"
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    var permissionState: String? {
        switch self {
        case .permissionsNotGranted(let authState):
            switch authState {
            case .notDetermined:
                return "Not Determined"
            case .restricted:
                return "Restricted"
            case .denied:
                return "Denied"
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
