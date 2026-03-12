import CoreBluetooth

public protocol PeripheralManager {
    init(
        delegate: (any CBPeripheralManagerDelegate)?,
        queue: dispatch_queue_t?,
        options: [String: Any]?
    )
}

extension CBPeripheralManager: PeripheralManager {}
