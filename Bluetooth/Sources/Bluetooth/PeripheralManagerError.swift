enum PeripheralManagerError {
    case invalidUUID
    case bluetoothNotEnabled
    case permissionsNotAccepted
    
    case addServiceError(String)
    
    case unknown
}
