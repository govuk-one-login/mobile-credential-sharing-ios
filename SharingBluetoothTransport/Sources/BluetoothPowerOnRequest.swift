import CoreBluetooth

public struct BluetoothPowerOnRequest<P: PeripheralManager> {
    public init() {
        // Empty init required to make struct public facing
    }
    
    public func callAsFunction() -> PeripheralManager {
        P.init(
            delegate: nil,
            queue: nil,
            options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]
        )
    }
}
