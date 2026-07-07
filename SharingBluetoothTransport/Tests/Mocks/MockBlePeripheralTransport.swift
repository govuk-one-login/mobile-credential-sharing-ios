import CoreBluetooth
import SharingBluetoothTransport

class MockBlePeripheralTransport: BlePeripheralTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    
    var didCallStartAdvertising: Bool = false
    var didCallSendData: Bool = false
    var didCallEndSession: Bool = false
    var endSessionAndNotify: Bool?
    var lastSentData: Data?
    
    init(mockPeripheralManagerState: CBManagerState = .poweredOn) {
        self.mockPeripheralManagerState = mockPeripheralManagerState
    }
    
    func peripheralManagerState() -> CBManagerState {
        return mockPeripheralManagerState
    }
    
    func startAdvertising() {
        didCallStartAdvertising = true
    }
    
    func endSession(andNotify: Bool) {
        didCallEndSession = true
        endSessionAndNotify = andNotify
    }

    func sendData(_ data: Data) {
        didCallSendData = true
        lastSentData = data
    }
}
