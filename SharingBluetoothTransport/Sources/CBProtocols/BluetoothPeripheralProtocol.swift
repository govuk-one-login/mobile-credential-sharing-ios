import CoreBluetooth
import Foundation

public protocol BluetoothPeripheralProtocol {
    /// The current connection state of the peripheral.
    var state: CBPeripheralState { get }
    
    /// The name of the peripheral.
    var name: String? { get }
    
    /// The unique, persistent identifier associated with the peer.
    var identifier: UUID { get }
    
    /// The delegate object that will receive peripheral events.
    var delegate: CBPeripheralDelegate? { get set }
    
    /// A list of a peripheral's discovered services.
    var services: [CBService]? { get }
    
    /// The maximum amount of data, in bytes, that can be sent to a characteristic in a single write type.
    func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int
    
    /// Discovers the specified services of the peripheral.
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    
    /// Discovers the specified characteristics of a service.
    func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]?,
        for service: CBService
    )
    
    /// Sets notifications or indications for the value of a specified characteristic.
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)
    
    /// Writes the value of a characteristic.
    func writeValue(
        _ data: Data,
        for characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType
    )
}

extension CBPeripheral: BluetoothPeripheralProtocol {}
