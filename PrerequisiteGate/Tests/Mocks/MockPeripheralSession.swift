import BluetoothTransport
import CoreBluetooth
import PrerequisiteGate

class MockPeripheralSession: PeripheralSessionProtocol {
    weak var delegate: (any BluetoothTransport.PeripheralSessionDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    init(mockPeripheralManagerState: CBManagerState = .poweredOn) {
        self.mockPeripheralManagerState = mockPeripheralManagerState
    }
    
    func peripheralManagerState() -> CBManagerState {
        return mockPeripheralManagerState
    }
}
