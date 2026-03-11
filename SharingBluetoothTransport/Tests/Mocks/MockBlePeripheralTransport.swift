import CoreBluetooth
import SharingBluetoothTransport

class MockBlePeripheralTransport: BlePeripheralTransportProtocol {
    weak var delegate: (any BluetoothTransportDelegate)?
    
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
