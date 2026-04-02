import CoreBluetooth
import SharingBluetoothTransport

class MockBlePeripheralTransport: BlePeripheralTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    
    var didCallStartAdvertising: Bool = false
    var didCallSendData: Bool = false
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
    
    func endSession() {
        
    }

    func sendData(_ data: Data) {
        didCallSendData = true
        lastSentData = data
    }
}
