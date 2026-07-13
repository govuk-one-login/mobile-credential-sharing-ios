import Foundation
import SharingBluetoothTransport

class MockBluetoothTransport: BluetoothTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    var shouldThrowOnStartAdvertising: Bool = false
    var didCallSendSessionData: Bool = false
    var didCallSendGattEnd: Bool = false
    var autoCompleteSend: Bool = true
    var lastSentSessionData: Data?
    var startScanningCalled = false
    var startScanningSession: BluetoothSessionProtocol?
    var startScanningShouldThrow: Error?
    var startTransportCalled = false
    var sendCalled = false
    
    
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

    func connect(in session: any BluetoothSessionProtocol) throws {
        if let error = startScanningShouldThrow { throw error }
        startScanningCalled = true
        startScanningSession = session
    }
    
    func startTransport() {
        startTransportCalled = true
    }

    func sendSessionData(_ data: Data) {
        didCallSendSessionData = true
        lastSentSessionData = data
        if autoCompleteSend {
            delegate?.bluetoothTransportDidFinishSending()
        }
    }
    
    func send(_ data: Data) {
        sendCalled = true
    }
    
    func sendGattEnd() {
        didCallSendGattEnd = true
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
    
    func bluetoothTransportDidStartSession() {
        delegate?.bluetoothTransportDidStartSession()
    }
}
