@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralAdvertisingManagerTests")
struct PeripheralAdvertisingManagerTests {
    let mockPeripheralManager = MockPeripheralManager()
    var peripheralManager: MockPeripheralManager
    var sut: PeripheralBluetoothSession?
    var serviceUUID: UUID = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID()
    
    init() {
        peripheralManager = mockPeripheralManager
        sut = PeripheralBluetoothSession(
            peripheralManager: peripheralManager,
            serviceUUID: UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID(),
        )
    }
    
    @Test("Session listens to changes from manager")
    func sessionListensToChangesFromManager() {
        #expect(mockPeripheralManager.delegate === sut)
    }
    
    @Test("serviceUUID matches the one passed in")
    func serviceUUIDMatches() {
        #expect(sut!.serviceCBUUID == CBUUID(nsuuid: serviceUUID))
        #expect(sut!.error == nil)
    }
    
    @Test("Advertising is stopped on deinit")
    mutating func advertisingStoppedOnDeinit() {
        sut = nil
        
        #expect(mockPeripheralManager.didStopAdvertising == true)
    }
    
    @Test("When bluetooth turns on, remove existing services")
    func removeExistingServicesOnBluetoothTurnedOn() {
        sut!.initiateAdvertising(mockPeripheralManager)
        #expect(mockPeripheralManager.didRemoveService)
    }
    
    @Test("When bluetooth turns on, add new service")
    func addNewServiceOnBluetoothTurnedOn() {
        sut!.initiateAdvertising(mockPeripheralManager)
        #expect(mockPeripheralManager.addedService != nil)
        #expect(sut!.error == nil)
    }
    
    @Test("Starts advertising when bluetooth is powered on")
    func startsAdvertisingWhenPoweredOn() {
        sut!.initiateAdvertising(mockPeripheralManager)
        #expect(peripheralManager.didStartAdvertising)
        #expect(sut!.error == nil)
    }
    
    @Test("Succesfully starts advertising the added service")
    func succesfullyInitiatesAdvertising() {
        sut!.initiateAdvertising(mockPeripheralManager)
        
        #expect(sut!.error == nil)
        #expect(mockPeripheralManager.delegate === sut)
        #expect(peripheralManager.advertisedServiceID == sut!.serviceCBUUID)
        #expect(peripheralManager.didStartAdvertising == true)
    }
    
    @Test("Does not advertise when bluetooth not powered on")
    func doesNotInitiateAdvertisingWhenNotPoweredOn() {
        mockPeripheralManager.state = .poweredOff
        sut!.initiateAdvertising(mockPeripheralManager)
        
        #expect(sut!.error == .bluetoothNotEnabled)
        #expect(peripheralManager.didStartAdvertising == false)
        #expect(peripheralManager.didStopAdvertising == true)
    }
    
    @Test("checkBluetooth returns true when successful")
    func checkBluetoothSuccess() {
        #expect(sut!.checkBluetooth(.poweredOn))
        #expect(sut!.error == nil)
    }
    
    @Test("checkBluetooth returns correct errors")
    func checkBluetoothErrors() {
        for state in [CBManagerState.unknown, .resetting, .unauthorized, .unsupported, .poweredOff] {
            #expect(sut!.checkBluetooth(state) == false)
            switch state {
            case .unknown:
                #expect(sut!.error == .unknown)
            case .resetting, .unsupported, .poweredOff:
                #expect(sut!.error == .bluetoothNotEnabled)
            case .unauthorized:
                #expect(sut!.error == .permissionsNotAccepted)
            default:
                break
            }
        }
    }
}
