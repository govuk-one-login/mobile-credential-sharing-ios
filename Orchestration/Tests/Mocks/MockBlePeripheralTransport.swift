import BluetoothTransport
import CoreBluetooth
import PrerequisiteGate

class MockBlePeripheralTransport: BlePeripheralTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    
    var endSessionCalled: Bool = false
    
    init(mockPeripheralManagerState: CBManagerState = .poweredOn) {
        self.mockPeripheralManagerState = mockPeripheralManagerState
    }
    
    func peripheralManagerState() -> CBManagerState {
        return mockPeripheralManagerState
    }
    
    func startAdvertising() {}
    
    func endSession() {
        endSessionCalled = true
    }
}
