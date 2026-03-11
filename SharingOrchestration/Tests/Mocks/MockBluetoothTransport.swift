import SharingBluetoothTransport
import Foundation

class MockBluetoothTransport: BluetoothTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    
    func startAdvertising(in session: any BluetoothSessionProtocol) throws {
        if let blePeripheralTransport {
            let connectionHandle = ConnectionHandle(blePeripheralTransport: blePeripheralTransport)
            try session.setConnection(connectionHandle)
        }
        // Simulates successful detection of Bluetooth State change
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
