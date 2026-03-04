import BluetoothTransport
import Foundation

class MockBluetoothTransport: BluetoothTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    
    func startAdvertising(in session: any BluetoothSessionProtocol) throws {
        // Simulates successful detection of Bluetooth State change
        if let blePeripheralTransport {
            let connectionHandle = ConnectionHandle(bluetoothTransport: blePeripheralTransport)
            try session.setConnection(connectionHandle)
        }
        bluetoothTransportDidStartAdvertising()
    }
}

extension MockBluetoothTransport: BluetoothTransportDelegate {
    func bluetoothTransportDidPowerOn() {
        
    }
    
    func bluetoothTransportDidFail(with error: PeripheralError) {
        
    }
    
    func bluetoothTransportDidStartAdvertising() {
        delegate?.bluetoothTransportDidStartAdvertising()
    }
    
    func bluetoothTransportConnectionDidConnect() {
        delegate?.bluetoothTransportConnectionDidConnect()
    }
    
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        
    }
    
    func bluetoothTransportDidReceiveMessageEndRequest() {
        
    }
}
