import CoreBluetooth

extension BleCentralTransport: CBPeripheralDelegate {
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: (any Error)?
    ) {
        handleDidDiscoverServices(error: error)
    }
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        handleDidDiscoverCharacteristics(for: service, error: error)
    }
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        handleDidUpdateNotificationState(for: characteristic, error: error)
    }
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        handleDidUpdateValue(for: characteristic, error: error)
    }
}
