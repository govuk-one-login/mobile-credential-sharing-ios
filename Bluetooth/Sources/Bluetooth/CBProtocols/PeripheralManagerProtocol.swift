import CoreBluetooth
import Foundation

public protocol PeripheralManagerProtocol {
    var authorization: CBManagerAuthorization { get }
    
    var state: CBManagerState { get }
    var delegate: CBPeripheralManagerDelegate? { get set }
    var isAdvertising: Bool { get }
    
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

extension CBPeripheralManager: PeripheralManagerProtocol {
    
    override public var authorization: CBManagerAuthorization {
        return CBPeripheralManager.authorization
    }
}
