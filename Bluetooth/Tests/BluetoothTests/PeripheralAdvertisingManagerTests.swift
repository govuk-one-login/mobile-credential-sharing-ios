@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralAdvertisingManagerTests")
struct PeripheralAdvertisingManagerTests {
    var sut = PeripheralAdvertisingManager { _ in
        MockPeripheralManagerFactory()
    }
    
    var cbUUID: CBUUID
    
    var service: CBMutableService
    
    init() {
        cbUUID = CBUUID(string: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")
        let characteristic = CBMutableCharacteristic(
            type: CBUUID(nsuuid: UUID()),
            properties: [.notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        let descriptor = CBMutableDescriptor(
            type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
            value: "Characteristic"
        )
        characteristic.descriptors = [descriptor]
        
        service = CBMutableService(type: cbUUID, primary: true)
        
        service.characteristics = [characteristic]
        service.includedServices = []
    }
    
    
    @Test("Adds a service successfully")
    func succesfullyAddsService() {
        
        #expect(sut.addedServices.isEmpty)
        
        sut.addService(service)
        
        #expect(sut.addedServices.contains(service))
        #expect(sut.error == nil)
    }
    
    @Test("Does not allow duplicate services")
    func preventDuplicateService() {
        
        #expect(sut.addedServices.isEmpty)
        
        sut.addService(service)
        
        #expect(sut.addedServices.contains(service))
        
        sut.addService(service)
        
        #expect(sut.error == .addServiceError("Already contains this service"))
        #expect(sut.addedServices.count == 1)
    }
    
    @Test("Added services cannot be empty when advertising")
    func servicesCannotBeEmpty() {
        sut.startAdvertising()
        
        #expect(sut.addedServices.isEmpty)
        #expect(sut.error == .addServiceError("Added services cannot be empty"))
    }
    
    @Test
    func succesfullyStartsAdvertising() {
        sut.addService(service)
        sut.startAdvertising()
        
        #expect(sut.error == nil)
    }
    
    @Test func stopsAdvertising() {
        sut.addService(service)
        sut.startAdvertising()
        
        #expect(sut.error == nil)
    }
}

struct MockPeripheralManagerFactory: PeripheralManaging {
        
    var state: CBManagerState
    
    init(state: CBManagerState = .poweredOn) {
        self.state = state
    }
    
    func startAdvertising(_ advertisementData: [String: Any]?) {
        
    }
    
    func stopAdvertising() {
        
    }
    
    func add(_ service: CBMutableService) {
        
    }
    
    func remove(_ service: CBMutableService) {
        
    }
    
    func removeAllServices() {
        
    }
    
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals: [CBCentral]?) -> Bool {
        return true
    }
    
    
}
