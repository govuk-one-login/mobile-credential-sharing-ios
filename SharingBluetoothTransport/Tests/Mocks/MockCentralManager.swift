import Foundation
import SharingBluetoothTransport

class MockCentral: BluetoothCentralProtocol {
    var identifier: UUID = UUID()
    var maximumUpdateValueLength: Int = 512
}
