import CoreBluetooth
import Foundation

public protocol BluetoothCentralProtocol {
    var identifier: UUID { get }
    var maximumUpdateValueLength: Int { get }
}

extension CBCentral: BluetoothCentralProtocol {}
