enum PeripheralManagerError: Equatable, Error {
    case bluetoothNotEnabled
    case permissionsNotAccepted
    
    case addServiceError(String)
    case startAdvertisingError(String)
    case updateValueError(String)
    
    case unknown
}
