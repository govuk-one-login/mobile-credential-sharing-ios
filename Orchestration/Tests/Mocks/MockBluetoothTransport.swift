import BluetoothTransport
import Foundation

class MockBluetoothTransport: BluetoothTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    
    func startAdvertising(in session: any BluetoothSessionProtocol) throws {
        // Simulates successful detection of Bluetooth State change
        bluetoothTransportDidStartAdvertising()
    }
}

extension MockBluetoothTransport: BluetoothTransportDelegate {
    func bluetoothTransportDidStartAdvertising() {
        delegate?.bluetoothTransportDidStartAdvertising()
    }
    
    func bluetoothTransportConnectionDidConnect() {
        
    }
    
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        
    }
    
    func bluetoothTransportDidReceiveMessageEndRequest() {
        
    }
}
