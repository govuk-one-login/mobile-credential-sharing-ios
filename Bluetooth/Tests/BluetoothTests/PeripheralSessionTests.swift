@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralSessionTests")
struct PeripheralSessionTests {
    let mockPeripheralManager = MockPeripheralManager()
    var peripheralManager: MockPeripheralManager
    var sut: PeripheralSession?
    var serviceUUID: UUID = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID()
    let characteristics: [CBMutableCharacteristic]
    
    init() {
        peripheralManager = mockPeripheralManager
        sut = PeripheralSession(
            peripheralManager: peripheralManager,
            serviceUUID: UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID(),
        )
        self.characteristics = CharacteristicType.allCases.compactMap(
            { CBMutableCharacteristic(characteristic: $0) }
        )
    }
    
    @Test("Session listens to changes from manager")
    func sessionListensToChangesFromManager() {
        #expect(mockPeripheralManager.delegate === sut)
    }
    
    @Test("serviceUUID matches the one passed in")
    func serviceUUIDMatches() {
        #expect(sut?.serviceCBUUID == CBUUID(nsuuid: serviceUUID))
        #expect(sut?.error == nil)
    }
    
    @Test("Advertising is stopped on deinit")
    mutating func advertisingStoppedOnDeinit() {
        sut = nil
        
        #expect(mockPeripheralManager.didStopAdvertising == true)
    }
    
    @Test("When bluetooth turns on, remove existing services")
    func removeExistingServicesOnBluetoothTurnedOn() {
        sut?.startAdvertising(mockPeripheralManager)
        #expect(mockPeripheralManager.didRemoveService)
    }
    
    @Test("When bluetooth turns on, add new service")
    func addNewServiceOnBluetoothTurnedOn() {
        sut?.startAdvertising(mockPeripheralManager)
        #expect(mockPeripheralManager.addedService != nil)
        #expect(sut?.error == nil)
    }
    
    @Test("Starts advertising when bluetooth is powered on")
    func startsAdvertisingWhenPoweredOn() {
        sut?.startAdvertising(mockPeripheralManager)
        #expect(peripheralManager.didStartAdvertising)
        #expect(sut?.error == nil)
    }
    
    @Test("Successfully starts advertising the added service")
    func successfullyInitiatesAdvertising() {
        sut?.startAdvertising(mockPeripheralManager)
        
        #expect(sut?.error == nil)
        #expect(mockPeripheralManager.delegate === sut)
        #expect(peripheralManager.advertisedServiceID == sut?.serviceCBUUID)
        #expect(peripheralManager.didStartAdvertising == true)
    }
    
    @Test("Does not advertise when bluetooth not powered on")
    func doesNotStartAdvertisingWhenNotPoweredOn() {
        mockPeripheralManager.state = .poweredOff
        sut?.startAdvertising(mockPeripheralManager)
        
        #expect(sut?.error == .bluetoothNotEnabled)
        #expect(peripheralManager.didStartAdvertising == false)
        #expect(peripheralManager.didStopAdvertising == true)
    }
    
    @Test("checkBluetooth returns true when successful")
    func checkBluetoothSuccess() {
        #expect(sut?.bluetoothPoweredOn(.poweredOn) ?? false)
        #expect(sut?.error == nil)
    }
    
    @Test("checkBluetooth returns correct errors")
    func checkBluetoothErrors() {
        for state in [CBManagerState.unknown, .resetting, .unauthorized, .unsupported, .poweredOff] {
            #expect(sut?.bluetoothPoweredOn(state) == false)
            switch state {
            case .unknown:
                #expect(sut?.error == .unknown)
            case .resetting, .unsupported, .poweredOff:
                #expect(sut?.error == .bluetoothNotEnabled)
            case .unauthorized:
                #expect(sut?.error == .permissionsNotGranted)
            default:
                break
            }
        }
    }
    
    @Test("Stores subscribed central")
    func storesSubscribedCentral() throws {
        #expect(sut?.subscribedCentrals.isEmpty ?? false)
        let characteristic = try #require(characteristics.first)

        sut?.centralDidSubscribe(central: MockCentral(), didSubscribeTo: characteristic)
        
        #expect(sut?.subscribedCentrals.count == 1)
        #expect(sut?.error == nil)
    }
    
    @Test("Stored central contains subscribed characteristic")
    func storedCentralContainsSubscribedCharacteristic() throws {
        let characteristic = try #require(characteristics.first)
        
        sut?.centralDidSubscribe(central: MockCentral(), didSubscribeTo: characteristic)
        
        #expect(sut?.subscribedCentrals.first?.key == characteristic)
    }
    
    @Test("Correct characteristics are added to GATT service")
    func subscribedCharacteristicIsPartOfGATTService() throws {
        let serviceCBUUID = try #require(sut?.serviceCBUUID)
        let service = sut?.mutableServiceWithServiceCharacterics(serviceCBUUID)
        
        let expectedUUIDs = Set(characteristics.map { $0.uuid })
        let serviceUUIDs = Set(service?.characteristics?.map { $0.uuid } ?? [])
        
        
        #expect(expectedUUIDs == serviceUUIDs)
    }
        
    @Test("Removes duplicate subscribed centrals")
    func removesDuplicateSubscribedCentrals() throws {
        let central = MockCentral()
        let characteristic = try #require(characteristics.first)
        
        #expect(sut?.subscribedCentrals.count == 0)
        sut?.centralDidSubscribe(central: central, didSubscribeTo: characteristic)
        sut?.centralDidSubscribe(central: central, didSubscribeTo: characteristic)
        
        #expect(sut?.subscribedCentrals[characteristic]?.count == 1)
    }
    
    @Test("Handle error function correctly sets error")
    func handleErrorSetsError() {
        for error in [PeripheralManagerError.addServiceError(""), .startAdvertisingError(""), .updateValueError("")] {
            sut?.handleError(error)
            switch error {
            case .addServiceError:
                #expect(sut?.error == error)
            case .startAdvertisingError:
                #expect(sut?.error == error)
            case .updateValueError:
                #expect(sut?.error == error)
            default:
                break
            }
        }
    }
}
