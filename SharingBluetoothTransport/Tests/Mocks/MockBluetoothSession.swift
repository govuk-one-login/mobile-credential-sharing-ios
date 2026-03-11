import BluetoothTransport
import UIKit

class MockBluetoothSession: BluetoothSessionProtocol {
    var serviceUUID: UUID?
    var connectionHandle: ConnectionHandle?
    
    func setConnection(_ connectionHandle: ConnectionHandle) throws {
        
    }
}
