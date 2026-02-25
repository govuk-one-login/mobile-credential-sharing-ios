import BluetoothTransport
import CoreBluetooth
import PrerequisiteGate

class MockPeripheralSession: BlePeripheralTransportProtocol {
    weak var delegate: (any BlePeripheralTransportDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    init(mockPeripheralManagerState: CBManagerState = .poweredOn) {
        self.mockPeripheralManagerState = mockPeripheralManagerState
    }
    
    func peripheralManagerState() -> CBManagerState {
        return mockPeripheralManagerState
    }
    
    func startAdvertising() {}
    
    func endSession() {}
}
