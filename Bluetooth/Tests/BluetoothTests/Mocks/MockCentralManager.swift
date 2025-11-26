import Bluetooth
import Foundation

class MockCentral: BluetoothCentral {
    var identifier: UUID = UUID()
    var maximumUpdateValueLength: Int = 1
}
