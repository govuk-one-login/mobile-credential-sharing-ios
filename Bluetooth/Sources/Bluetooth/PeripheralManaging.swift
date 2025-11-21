import CoreBluetooth
import Foundation

public protocol PeripheralManaging {
    var state: CBManagerState { get }
    var delegate: CBPeripheralManagerDelegate? { get set }
    
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

extension CBPeripheralManager: PeripheralManaging { }
