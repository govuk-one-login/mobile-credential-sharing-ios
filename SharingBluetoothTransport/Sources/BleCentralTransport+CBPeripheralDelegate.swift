import CoreBluetooth

extension BleCentralTransport: CBPeripheralDelegate {
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: (any Error)?
    ) {
        handleDidDiscoverServices(for: peripheral, error: error)
    }
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        handleDidDiscoverCharacteristics(for: service, error: error)
    }
}
