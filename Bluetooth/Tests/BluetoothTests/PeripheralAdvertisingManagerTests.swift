@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralAdvertisingManagerTests")
struct PeripheralAdvertisingManagerTests {
    var peripheralManager: MockPeripheralManager
    var sut: PeripheralAdvertisingManager
    var cbUUID: CBUUID
    var characteristic: CBMutableCharacteristic
    
    init() {
        peripheralManager = MockPeripheralManager()
        sut = PeripheralAdvertisingManager(peripheralManager: peripheralManager)
        cbUUID = CBUUID(string: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE")
        characteristic = CBMutableCharacteristic(
            type: CBUUID(nsuuid: UUID()),
            properties: ServiceCharacteristic.state.properties,
            value: nil,
            permissions: [.readable, .writeable]
        )
        let descriptor = CBMutableDescriptor(
            type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
            value: "Wallet Sharing initiate Characteristic"
        )
        characteristic.descriptors = [descriptor]
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
    
    @Test("An error occurs on start advertising")
    func startAdvertisingError() {
        sut.peripheralManagerDidStartAdvertising(CBPeripheralManager(), error: PeripheralManagerError.unknown)
        #expect(sut.error == .startAdvertisingError("The operation couldn’t be completed. (Bluetooth.PeripheralManagerError error 5.)"))
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
    
    @Test("Stores subscribed central")
    func storesSubscribedCentral() {
        #expect(sut.subscribedCentrals.isEmpty)
        sut.centralDidSubscribe(central: MockCentralManager(), didSubscribeTo: characteristic)
        
        #expect(sut.subscribedCentrals.count == 1)
        #expect(sut.error == nil)
    }
}
