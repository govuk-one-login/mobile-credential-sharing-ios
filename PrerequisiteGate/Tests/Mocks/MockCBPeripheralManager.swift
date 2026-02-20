import BluetoothTransport
import CoreBluetooth

class MockCBPeripheralManager: PeripheralManager {
    nonisolated(unsafe) static var initCalled = false
    nonisolated(unsafe) static var options: [String: Any]? = nil
    required init(
        delegate: (any CBPeripheralManagerDelegate)?,
        queue: dispatch_queue_t?,
        options: [String: Any]?
    ) {
        MockCBPeripheralManager.initCalled = true
        MockCBPeripheralManager.options = options
    }
}
