import CoreBluetooth
import Foundation

extension BleCentralTransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        handleDidUpdateState(for: central)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        handleDidDiscoverPeripheral(for: peripheral)
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        handleDidConnect(peripheral)
    }
}
