import CoreBluetooth

enum PeripheralError: Equatable, Error, LocalizedError {
    case notPoweredOn(CBManagerState)
    case permissionsNotGranted(CBManagerAuthorization)
    
    case addServiceError(String)
    case startAdvertisingError(String)
    case updateValueError(String)
    
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notPoweredOn(let state):
            return "Bluetooth is not ready. Current state: \(state)"
        case .permissionsNotGranted(let authState):
            return "App does not have the required Bluetooth permissions. Current state: \(authState)"
        case .addServiceError(let description):
            return "Failed to add service: \(description)"
        case .startAdvertisingError(let description):
            return "Failed to start advertising: \(description)"
        case .updateValueError(let description):
            return "Failed to update value: \(description)"
        case .unknown:
            return "Unknown error"
        }
    }
}
