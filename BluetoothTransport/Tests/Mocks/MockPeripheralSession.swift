import BluetoothTransport
import CoreBluetooth

class MockPeripheralSession: PeripheralSessionProtocol {
    weak var delegate: (any PeripheralSessionDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    
    var didCallStartAdvertising: Bool = false
    
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
}
