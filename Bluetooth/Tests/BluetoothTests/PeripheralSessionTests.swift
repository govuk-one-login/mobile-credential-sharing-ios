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
        MockPeripheralManager.authorization = .allowedAlways
    }
    
    @Test("Session listens to changes from manager")
    func sessionListensToChangesFromManager() {
        #expect(mockPeripheralManager.delegate === sut)
    }
    
    @Test("serviceUUID matches the one passed in")
    func serviceUUIDMatches() {
        #expect(sut?.serviceCBUUID == CBUUID(nsuuid: serviceUUID))
    }
    
    @Test("Advertising is stopped on deinit")
    mutating func advertisingStoppedOnDeinit() {
        sut = nil
        
        #expect(mockPeripheralManager.didStopAdvertising == true)
    }
    
    @Test("When bluetooth turns on, remove existing services")
    func removeExistingServicesOnBluetoothTurnedOn() {
        sut?.handleBluetoothInitialisation(for: mockPeripheralManager)
        #expect(mockPeripheralManager.didRemoveService)
    }
    
    @Test("When bluetooth turns on, add new service")
    func addNewServiceOnBluetoothTurnedOn() {
        sut?.handleBluetoothInitialisation(for: mockPeripheralManager)
        #expect(mockPeripheralManager.addedService != nil)
    }
    
    @Test("Starts advertising when bluetooth is powered on")
    func startsAdvertisingWhenPoweredOn() {
        sut?.handleBluetoothInitialisation(for: mockPeripheralManager)
        #expect(peripheralManager.didStartAdvertising)
    }
    
    @Test("Successfully starts advertising the added service")
    func successfullyInitiatesAdvertising() {
        sut?.handleBluetoothInitialisation(for: mockPeripheralManager)
        
        #expect(mockPeripheralManager.delegate === sut)
        #expect(peripheralManager.advertisedServiceID == sut?.serviceCBUUID)
        #expect(peripheralManager.didStartAdvertising == true)
    }
    
    @Test("Does not advertise when bluetooth not powered on")
    func doesNotStartAdvertisingWhenNotPoweredOn() {
        for state in [
            CBManagerState.unknown,
            .resetting,
            .unauthorized,
            .unsupported,
            .poweredOff
        ] {
            mockPeripheralManager.state = state
            sut?.handleBluetoothInitialisation(for: mockPeripheralManager)
            
            #expect(mockPeripheralManager.didStartAdvertising == false)
        }
    }
    
    @Test("Does not advertise when permissions not granted")
    func doesNotStartAdvertitingWhenPermissionsNotGranted() {
        for auth in [CBManagerAuthorization.notDetermined, .restricted, .denied] {
            MockPeripheralManager.authorization = auth
            sut?.handleBluetoothInitialisation(for: peripheralManager)
            
            #expect(mockPeripheralManager.didStartAdvertising == false)
        }
    }
    
    @Test("Stores subscribed central")
    func storesSubscribedCentral() throws {
        #expect(sut?.subscribedCentrals.isEmpty ?? false)
        let characteristic = try #require(characteristics.first)

        sut?.centralDidSubscribe(central: MockCentral(), didSubscribeTo: characteristic)
        
        #expect(sut?.subscribedCentrals.count == 1)
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
    
    @Test("PeripheralError descriptions are correct")
    func peripheralErrorDescriptions() {
        for error in [
            PeripheralError.notPoweredOn(CBManagerState.poweredOff),
            .addServiceError("service"),
            .permissionsNotGranted(CBManagerAuthorization.denied),
            .startAdvertisingError("advertising"),
            .updateValueError("value"),
            .unknown
        ] {
            switch error {
            case .notPoweredOn(let state):
                #expect(
                    error.errorDescription == "Bluetooth is not ready. Current state: \(state)."
                )
            case .permissionsNotGranted:
                #expect(
                    error.errorDescription == "App does not have the required Bluetooth permissions. Current state: \(error.permissionState!)."
                )
            case .addServiceError(let description):
                #expect(
                    error.errorDescription == "Failed to add service: \(description)."
                )
            case .startAdvertisingError(let description):
                #expect(
                    error.errorDescription == "Failed to start advertising: \(description)."
                )
            case .updateValueError(let description):
                #expect(
                    error.errorDescription == "Failed to update value: \(description)."
                )
            case .unknown:
                #expect(error.errorDescription == "An unknown error has occured.")
            }
        }
    }
}
