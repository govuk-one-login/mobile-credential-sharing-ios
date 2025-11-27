enum PeripheralManagerError: Equatable, Error {
    case bluetoothNotEnabled
    case permissionsNotGranted
    
    case addServiceError(String)
    case startAdvertisingError(String)
    case updateValueError(String)
    
    case unknown
}
