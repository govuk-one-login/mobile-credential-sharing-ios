@testable import Bluetooth
import CoreBluetooth
import Foundation

class MockPeripheralManager: PeripheralManaging {
    weak var delegate: (any CBPeripheralManagerDelegate)?
    
    var state: CBManagerState
    
    var addedServices: [CBMutableService] = []
    var advertisedServiceID: CBUUID?
    var didStartAdvertising: Bool = false
    
    init(state: CBManagerState = .poweredOn) {
        self.state = state
    }
    
    func startAdvertising(_ advertisementData: [String: Any]?) {
        advertisedServiceID = (advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.first
        didStartAdvertising = true
    }
    
    func stopAdvertising() {
        
    }
    
    func add(_ service: CBMutableService) {
        addedServices.append(service)
    }
    
    func remove(_ service: CBMutableService) {
        
    }
    
    func removeAllServices() {
        
    }
    
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals: [CBCentral]?) -> Bool {
        return true
    }
}
