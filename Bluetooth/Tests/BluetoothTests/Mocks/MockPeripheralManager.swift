import CoreBluetooth
import Foundation

@testable import Bluetooth

class MockPeripheralManager: PeripheralManagerProtocol {
    var authorization: CBManagerAuthorization = .allowedAlways

    var state: CBManagerState

    weak var delegate: (any CBPeripheralManagerDelegate)?

    var isAdvertising: Bool = false

    // MARK: - Tracking Properties
    var addedService: CBMutableService?
    var advertisedServiceID: CBUUID?
    var didRemoveService: Bool = false
    var lastResponseResult: CBATTError.Code?
    var didRespondToRequest: Bool = false

    init(state: CBManagerState = .poweredOn) {
        self.state = state
    }

    // MARK: - Advertising
    func startAdvertising(_ advertisementData: [String: Any]?) {
        advertisedServiceID = (advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.first
        isAdvertising = true
    }

    func stopAdvertising() {
        isAdvertising = false
    }

    // MARK: - Service Management
    func add(_ service: CBMutableService) {
        addedService = service
    }

    func remove(_ service: CBMutableService) {
        if addedService?.uuid == service.uuid {
            addedService = nil
        }
    }

    func removeAllServices() {
        didRemoveService = true
        addedService = nil
    }

    // MARK: - Communication
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals: [CBCentral]?) -> Bool {
        // Return true to simulate a successful send by default
        return true
    }

    /// Responds to an ATT request.
    func respond(to request: any ATTRequestProtocol, withResult result: CBATTError.Code) {
        self.didRespondToRequest = true
        self.lastResponseResult = result
    }
}
