import CoreBluetooth
import SharingBluetoothTransport

class MockCBPeripheralManager: PeripheralManager {
    nonisolated(unsafe) static var initCalled = false
    nonisolated(unsafe) static var options: [String: Any]?
    required init(
        delegate: (any CBPeripheralManagerDelegate)?,
        queue: dispatch_queue_t?,
        options: [String: Any]?
    ) {
        MockCBPeripheralManager.initCalled = true
        MockCBPeripheralManager.options = options
    }
}
