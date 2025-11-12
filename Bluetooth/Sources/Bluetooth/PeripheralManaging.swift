import CoreBluetooth
import Foundation

public protocol PeripheralManaging {
    var state: CBManagerState { get }
    
    func startAdvertising(_ advertisementData: [String: Any]?)
    func stopAdvertising()
    
    func add(_ service: CBMutableService)
    func remove(_ service: CBMutableService)
    func removeAllServices()
    
    func updateValue(
        _ value: Data,
        for characteristic: CBMutableCharacteristic,
        onSubscribedCentrals: [CBCentral]?
    ) -> Bool
}

extension PeripheralManaging where Self == CBPeripheralManager {
    public static func `default`(delegate: CBPeripheralManagerDelegate) -> Self {
        CBPeripheralManager(delegate: delegate, queue: nil, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: true,
            CBPeripheralManagerOptionRestoreIdentifierKey: "PeripheralAdvertisingManager"
        ])
    }
}

extension CBPeripheralManager: PeripheralManaging { }
