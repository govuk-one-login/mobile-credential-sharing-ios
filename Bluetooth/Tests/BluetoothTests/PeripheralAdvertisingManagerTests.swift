@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralAdvertisingManagerTests")
struct PeripheralAdvertisingManagerTests {
    let mockPeripheralManager = MockPeripheralManager()
    var peripheralManager: MockPeripheralManager
    var sut: PeripheralAdvertisingManager
    var serviceUUID: UUID = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID()
    
    init() {
        peripheralManager = mockPeripheralManager
        sut = PeripheralAdvertisingManager(
            peripheralManager: peripheralManager,
            serviceUUID: UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID(),
            beginAdvertising: true
        )
    }
    
    
    @Test("Adds a service successfully")
    func succesfullyAddsService() {
        #expect(sut.addedServices.contains(where: { $0.uuid == sut.serviceCBUUID }))
        #expect(sut.error == nil)
    }
    
    @Test("Expose an error when attempting to add a duplicate service")
    func preventDuplicateService() {
        #expect(sut.addedServices.contains(where: { $0.uuid == sut.serviceCBUUID }))
        
        sut.addService(sut.serviceCBUUID)
        
        #expect(sut.error == .addServiceError("Already contains this service"))
        #expect(sut.addedServices.count == 1)
        #expect(peripheralManager.didStartAdvertising == false)
    }
    
    @Test("Prevent advertising when there are no services added")
    func servicesCannotBeEmpty() {
        sut.removeServices()
        #expect(sut.addedServices.isEmpty)
        
        sut.startAdvertising()
        #expect(sut.error == .addServiceError("Added services cannot be empty"))
        #expect(peripheralManager.didStartAdvertising == false)
    }
    
    @Test("Succesfully starts advertising the added service")
    func succesfullyInitiatesAdvertising() {
        sut.initiateAdvertising(mockPeripheralManager)
        
        #expect(sut.error == nil)
        #expect(mockPeripheralManager.delegate === sut)
        #expect(peripheralManager.addedServices.contains(where: { $0.uuid == sut.serviceCBUUID }))
        #expect(peripheralManager.advertisedServiceID == sut.serviceCBUUID)
        #expect(peripheralManager.didStartAdvertising == true)
    }
    
    @Test("Does not start advertising when bluetooth not powered on")
    func doesNotInitiateAdvertisingWhenNotPoweredOn() {
        sut.addService(sut.serviceCBUUID)
        sut.initiateAdvertising(MockPeripheralManager(state: .poweredOff))
        
        #expect(sut.error == .bluetoothNotEnabled)
        #expect(peripheralManager.didStartAdvertising == false)
    }
    
    @Test("Successfully stops advertising")
    func stopsAdvertising() {
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
