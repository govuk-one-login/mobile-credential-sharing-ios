import CoreBluetooth
import Foundation

public protocol BluetoothPeripheralProtocol {
    var state: CBPeripheralState { get }
    var name: String? { get }
    var identifier: UUID { get }
    var delegate: CBPeripheralDelegate? { get set }
    var services: [CBService]? { get }
    func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]?,
        for service: CBService
    )
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)
    func writeValue(
        _ data: Data,
        for characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType
    )
}

extension CBPeripheral: BluetoothPeripheralProtocol {}
