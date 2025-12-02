import CoreBluetooth
import Foundation

public protocol BluetoothCentral {
    var identifier: UUID { get }
    var maximumUpdateValueLength: Int { get }
}

extension CBCentral: BluetoothCentral {}
