import CoreBluetooth
import Foundation

public protocol BluetoothPeripheralProtocol {
    var state: CBPeripheralState { get }
    var name: String? { get }
    var identifier: UUID { get }
    var delegate: CBPeripheralDelegate? { get set }
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    var services: [CBService]? { get }
    func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]?,
        for service: CBService
    )
}

extension CBPeripheral: BluetoothPeripheralProtocol {}
