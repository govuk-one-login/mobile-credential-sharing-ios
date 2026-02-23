import BluetoothTransport
import Foundation

class MockBluetoothTransport: BluetoothTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var peripheralSession: PeripheralSessionProtocol?
    
    func startAdvertising(in session: any BluetoothSessionProtocol) throws {
        // Simulates successful detection of Bluetooth State change
        peripheralSessionDidUpdateState(withError: nil)
    }
}

extension MockBluetoothTransport: PeripheralSessionDelegate {
    func peripheralSessionDidUpdateState(withError error: PeripheralError?) {
        // Simulates successful advertising
        peripheralSessionDidStartAdvertising()
    }
    
    func peripheralSessionDidStartAdvertising() {
        delegate?.bluetoothTransportDidStartAdvertising()
    }
    
    func peripheralSessionDidReceiveMessageData(_ messageData: Data) {
        
    }
    
    func peripheralSessionDidReceiveMessageEndRequest() {
        
    }
}
