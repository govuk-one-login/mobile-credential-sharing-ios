import CoreBluetooth
import Foundation

public protocol BluetoothPeripheralProtocol {
    var state: CBPeripheralState { get }
    var delegate: CBPeripheralDelegate? { get set }
}

extension CBPeripheral: BluetoothPeripheralProtocol {}
