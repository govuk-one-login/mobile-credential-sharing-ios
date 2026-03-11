import BluetoothTransport
import Foundation

class MockCentral: BluetoothCentralProtocol {
    var identifier: UUID = UUID()
    var maximumUpdateValueLength: Int = 1
}
