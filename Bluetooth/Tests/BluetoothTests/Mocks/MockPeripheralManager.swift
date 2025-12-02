@testable import Bluetooth
import CoreBluetooth
import Foundation

class MockPeripheralManager: PeripheralManagerProtocol {
    nonisolated(unsafe) static var authorization: CBManagerAuthorization = .allowedAlways
    
    weak var delegate: (any CBPeripheralManagerDelegate)?
    
    var state: CBManagerState
    
    var addedService: CBMutableService?
    var advertisedServiceID: CBUUID?
    var didStartAdvertising: Bool = false
    var didStopAdvertising: Bool = false
    var didRemoveService: Bool = false
    
    init(state: CBManagerState = .poweredOn) {
        self.state = state
    }
    
    func startAdvertising(_ advertisementData: [String: Any]?) {
        advertisedServiceID = (advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.first
        didStartAdvertising = true
    }
    
    func stopAdvertising() {
        didStopAdvertising = true
    }
    
    func add(_ service: CBMutableService) {
        addedService = service
    }
    
    func remove(_ service: CBMutableService) {
        
    }
    
    func removeAllServices() {
        didRemoveService = true
        addedService = nil
    }
    
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals: [CBCentral]?) -> Bool {
        return true
    }
}
