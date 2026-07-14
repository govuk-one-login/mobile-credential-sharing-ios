import CoreBluetooth
@testable import SharingBluetoothTransport

class MockBluetoothPeripheral: BluetoothPeripheralProtocol {
    var state: CBPeripheralState = .disconnected
    var name: String? = "MockPeripheral"
    var identifier: UUID = UUID()
    weak var delegate: CBPeripheralDelegate?
    var services: [CBService]?
    var canSendWriteWithoutResponse: Bool = true

    var discoverServicesCalled = false
    var discoveredServiceUUIDs: [CBUUID]?
    var discoverCharacteristicsCalled = false
    var discoveredCharacteristicUUIDs: [CBUUID]?
    var discoveredForService: CBService?
    var setNotifyValueCalled = false
    var setNotifyCharacteristics: [CBCharacteristic] = []
    var writeValueCalled = false
    var writtenData: Data?
    var writtenCharacteristic: CBCharacteristic?
    var writtenType: CBCharacteristicWriteType?
    var allWrittenData: [Data] = []
    var maximumWriteValueLengthValue: Int = 512

    func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        maximumWriteValueLengthValue
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        discoverServicesCalled = true
        discoveredServiceUUIDs = serviceUUIDs
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        discoverCharacteristicsCalled = true
        discoveredCharacteristicUUIDs = characteristicUUIDs
        discoveredForService = service
    }
    
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        setNotifyValueCalled = true
        setNotifyCharacteristics.append(characteristic)
    }
    
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        writeValueCalled = true
        writtenData = data
        writtenCharacteristic = characteristic
        writtenType = type
        allWrittenData.append(data)
    }
}
