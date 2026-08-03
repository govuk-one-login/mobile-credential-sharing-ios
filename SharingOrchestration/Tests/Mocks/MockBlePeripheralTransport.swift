import CoreBluetooth
import SharingBluetoothTransport
import SharingPrerequisiteGate

class MockBlePeripheralTransport: BlePeripheralTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    
    var endSessionCalled: Bool = false
    var endSessionAndNotifyValue: Bool?
    
    init(mockPeripheralManagerState: CBManagerState = .poweredOn) {
        self.mockPeripheralManagerState = mockPeripheralManagerState
    }
    
    func peripheralManagerState() -> CBManagerState {
        return mockPeripheralManagerState
    }
    
    func startAdvertising() {}
    
    func endSession(andNotify: Bool) {
        endSessionCalled = true
        endSessionAndNotifyValue = andNotify
    }

    func send(_ data: Data) {}
}
