import BluetoothTransport
import CoreBluetooth

class MockCBPeripheralManager: PeripheralManager {
    nonisolated(unsafe) static var initCalled = false
    required init(
        delegate: (any CBPeripheralManagerDelegate)?,
        queue: dispatch_queue_t?,
        options: [String: Any]?
    ) {
        MockCBPeripheralManager.initCalled = true
    }
}
