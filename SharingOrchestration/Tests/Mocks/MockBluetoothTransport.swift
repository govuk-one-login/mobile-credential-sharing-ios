import Foundation
import SharingBluetoothTransport

class MockBluetoothTransport: BluetoothTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    var shouldThrowOnStartAdvertising: Bool = false
    var didCallSendSessionData: Bool = false
    var lastSentSessionData: Data?
    var startScanningCalled = false
    var startScanningSession: BluetoothSessionProtocol?
    var stopScanningCalled = false
    var startScanningShouldThrow: Error?
    var connectCalled: Bool = false
    
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

    func startScanning(in session: any BluetoothSessionProtocol) throws {
        if let error = startScanningShouldThrow { throw error }
        startScanningCalled = true
        startScanningSession = session
    }

    func stopScanning() {
        stopScanningCalled = true
    }
    
    func connect() {
        connectCalled = true
    }

    func sendSessionData(_ data: Data) {
        didCallSendSessionData = true
        lastSentSessionData = data
        delegate?.bluetoothTransportDidFinishSending()
    }
}

extension MockBluetoothTransport: BluetoothTransportDelegate {
    func bluetoothTransportDidPowerOn() {
        
    }
    
    func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        
    }
    
    func bluetoothTransportDidStartAdvertising() {
        delegate?.bluetoothTransportDidStartAdvertising()
    }
    
    func bluetoothTransportConnectionDidConnect() {
        delegate?.bluetoothTransportConnectionDidConnect()
    }

    func bluetoothTransportDidDiscover() {
        delegate?.bluetoothTransportDidDiscover()
    }
    
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        
    }
    
    func bluetoothTransportDidReceiveMessageEndRequest() {
        
    }
    
    func bluetoothTransportDidFinishSending() {
        
    }
}
