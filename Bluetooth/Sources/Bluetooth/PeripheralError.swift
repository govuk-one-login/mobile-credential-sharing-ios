import CoreBluetooth

public enum PeripheralError: Equatable, Error, LocalizedError {
    case notPoweredOn(CBManagerState)
    case permissionsNotGranted(CBManagerAuthorization)
    
    case addServiceError(String)
    case startAdvertisingError(String)
    
    case sessionEstablishmentError(String)
    
    case connectionTerminated
    
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .notPoweredOn:
            return "Bluetooth is not ready. Current state: \(poweredOnState ?? "Unknown")."
        case .permissionsNotGranted:
            return "App does not have the required Bluetooth permissions. Current state: \(permissionState ?? "Unknown")."
        case .addServiceError(let description):
            return "Failed to add service: \(description)."
        case .startAdvertisingError(let description):
            return "Failed to start advertising: \(description)."
        case .sessionEstablishmentError(let description):
            return "Session establishment failed: \(description)."
        case .connectionTerminated:
            return "Bluetooth disconnected unexpectedly."
        case .unknown:
            return "An unknown error has occured."
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
