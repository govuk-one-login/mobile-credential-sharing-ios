enum PeripheralManagerError: Equatable {
    case bluetoothNotEnabled
    case permissionsNotAccepted
    
    case addServiceError(String)
    
    case unknown
}
