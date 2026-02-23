import BluetoothTransport
import UIKit

class MockBluetoothSession: BluetoothSessionProtocol {
    var serviceUUID: UUID?
    
    func setConnection(serviceUUID: UUID) throws {}
}
