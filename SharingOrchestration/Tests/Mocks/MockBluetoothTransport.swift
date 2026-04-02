import Foundation
import SharingBluetoothTransport

class MockBluetoothTransport: BluetoothTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    var shouldThrowOnStartAdvertising: Bool = false
    var didCallSendSessionData: Bool = false
    var lastSentSessionData: Data?
    
    func startAdvertising(in session: any BluetoothSessionProtocol) throws {
        if shouldThrowOnStartAdvertising {
            throw PeripheralError.startAdvertisingError("Mock error")
        }
        if let blePeripheralTransport {
            let connectionHandle = ConnectionHandle(blePeripheralTransport: blePeripheralTransport)
            try session.setConnection(connectionHandle)
        }
        // Simulates successful detection of Bluetooth State change
        bluetoothTransportDidStartAdvertising()
    }

    func sendSessionData(_ data: Data) {
        didCallSendSessionData = true
        lastSentSessionData = data
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
