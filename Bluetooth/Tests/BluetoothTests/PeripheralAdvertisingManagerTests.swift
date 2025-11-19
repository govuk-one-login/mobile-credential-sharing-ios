@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralAdvertisingManagerTests")
struct PeripheralAdvertisingManagerTests {
    var sut = PeripheralAdvertisingManager(peripheralManager: MockPeripheralManagerFactory())
    var cbUUID: CBUUID
    
    init() {
        cbUUID = CBUUID(string: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")
        sut.removeServices()
        sut.beginAdvertising = true
    }
    
    
    @Test("Adds a service successfully")
    func succesfullyAddsService() {
        
        #expect(sut.addedServices.isEmpty)
        
        sut.addService(cbUUID)
        
        #expect(sut.addedServices.contains(where: { $0.uuid == cbUUID }))
        #expect(sut.error == nil)
    }
    
    @Test("Does not allow duplicate services")
    func preventDuplicateService() {
        #expect(sut.addedServices.isEmpty)
        
        sut.addService(cbUUID)
        
        #expect(sut.addedServices.contains(where: { $0.uuid == cbUUID }))
        
        sut.addService(cbUUID)
        
        #expect(sut.error == .addServiceError("Already contains this service"))
        #expect(sut.addedServices.count == 1)
    }
    
    @Test("Added services cannot be empty when advertising")
    func servicesCannotBeEmpty() {
        sut.startAdvertising()
        
        #expect(sut.addedServices.isEmpty)
        #expect(sut.error == .addServiceError("Added services cannot be empty"))
    }
    
    @Test("Succesfully starts advertising the added service")
    func succesfullyInitiatesAdvertising() {
        sut.addService(cbUUID)
        sut.initiateAdvertising(sut.peripheralManager)
        
        #expect(sut.error == nil)
        #expect(sut.peripheralManager.delegate === sut)
        #expect(((sut.peripheralManager as? MockPeripheralManagerFactory)!.addedServices).contains(where: { $0.uuid == cbUUID }))
        #expect(((sut.peripheralManager as? MockPeripheralManagerFactory)?.advertisedServiceID) == cbUUID)
    }
    
    @Test("Successfully stops advertising")
    func stopsAdvertising() {
        sut.addService(cbUUID)
        sut.startAdvertising()
        
        #expect(sut.error == nil)
    }
    
    @Test("checkBluetooth returns true when successful")
    func checkBluetoothSuccess() {
        #expect(sut.checkBluetooth(.poweredOn))
        #expect(sut.error == nil)
    }
    
    @Test("checkBluetooth returns correct errors")
    func checkBluetoothErrors() {
        for state in [CBManagerState.unknown, .resetting, .unauthorized, .unsupported, .poweredOff] {
            #expect(sut.checkBluetooth(state) == false)
            switch state {
            case .unknown:
                #expect(sut.error == .unknown)
            case .resetting, .unsupported, .poweredOff:
                #expect(sut.error == .bluetoothNotEnabled)
            case .unauthorized:
                #expect(sut.error == .permissionsNotAccepted)
            default:
                break
            }
        }
    }
}

class MockPeripheralManagerFactory: PeripheralManaging {
    weak var delegate: (any CBPeripheralManagerDelegate)?
    
    var state: CBManagerState
    
    var addedServices: [CBMutableService] = []
    var advertisedServiceID: CBUUID?
    
    init(state: CBManagerState = .poweredOn) {
        self.state = state
    }
    
    func startAdvertising(_ advertisementData: [String: Any]?) {
        advertisedServiceID = (advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.first
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
