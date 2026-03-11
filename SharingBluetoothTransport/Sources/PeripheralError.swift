import CoreBluetooth

public enum PeripheralError: Equatable, Error, LocalizedError {
    case notPoweredOn(CBManagerState)
    case permissionsNotGranted(CBManagerAuthorization)
    
    case addServiceError(String)
    case startAdvertisingError(String)
    
    case clientToServerError(String)
    
    case connectionTerminated

    case failedToNotifyEnd

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
        case .clientToServerError(let description):
            return "Client2Server message receipt failed: \(description)."
        case .connectionTerminated:
            return "Bluetooth disconnected unexpectedly."
        case .failedToNotifyEnd:
            return "Failed to notify GATT end command."
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
