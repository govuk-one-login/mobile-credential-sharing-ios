import CoreBluetooth
@testable import SharingBluetoothTransport

class MockBluetoothPeripheral: BluetoothPeripheralProtocol {
    var state: CBPeripheralState = .disconnected
    var name: String? = "MockPeripheral"
    var identifier: UUID = UUID()
    weak var delegate: CBPeripheralDelegate?
    var services: [CBService]?

    var discoverServicesCalled = false
    var discoveredServiceUUIDs: [CBUUID]?
    var discoverCharacteristicsCalled = false
    var discoveredCharacteristicUUIDs: [CBUUID]?
    var discoveredForService: CBService?

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        discoverServicesCalled = true
        discoveredServiceUUIDs = serviceUUIDs
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        discoverCharacteristicsCalled = true
        discoveredCharacteristicUUIDs = characteristicUUIDs
        discoveredForService = service
    }
}
