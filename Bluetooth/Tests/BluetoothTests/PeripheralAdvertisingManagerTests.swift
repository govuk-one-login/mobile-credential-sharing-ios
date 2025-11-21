@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralAdvertisingManagerTests")
struct PeripheralAdvertisingManagerTests {
    
    var peripheralManager: MockPeripheralManager
    var sut: PeripheralAdvertisingManager
    var cbUUID: CBUUID
    
    init() {
        peripheralManager = MockPeripheralManager()
        sut = PeripheralAdvertisingManager(peripheralManager: peripheralManager)
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
    
    @Test("Expose an error when attempting to add a duplicate service")
    func preventDuplicateService() {
        #expect(sut.addedServices.isEmpty)
        
        sut.addService(cbUUID)
        
        #expect(sut.addedServices.contains(where: { $0.uuid == cbUUID }))
        
        sut.addService(cbUUID)
        
        #expect(sut.error == .addServiceError("Already contains this service"))
        #expect(sut.addedServices.count == 1)
    }
    
    @Test("Prevent advertising when there are no services added")
    func servicesCannotBeEmpty() {
        sut.startAdvertising()
        
        #expect(sut.addedServices.isEmpty)
        #expect(sut.error == .addServiceError("Added services cannot be empty"))
        #expect(peripheralManager.didStartAdvertising == false)
    }
    
    @Test("Succesfully starts advertising the added service")
    func succesfullyInitiatesAdvertising() {
        sut.addService(cbUUID)
        sut.initiateAdvertising(sut.peripheralManager)
        
        #expect(sut.error == nil)
        #expect(sut.peripheralManager.delegate === sut)
        #expect(peripheralManager.addedServices.contains(where: { $0.uuid == cbUUID }))
        #expect(peripheralManager.advertisedServiceID == cbUUID)
        #expect(peripheralManager.didStartAdvertising == true)
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
