@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralSessionTests")
struct PeripheralSessionTests {
    let mockPeripheralManager = MockPeripheralManager()
    var peripheralManager: MockPeripheralManager
    var mockDelegate = MockPeripheralSessionDelegate()
    var sut: PeripheralSession?
    var serviceUUID: UUID = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID()
    let characteristics: [CBMutableCharacteristic]
    
    init() {
        peripheralManager = mockPeripheralManager
        sut = PeripheralSession(
            peripheralManager: peripheralManager,
            serviceUUID: UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID(),
        )
        sut?.delegate = mockDelegate
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
        sut?.handleStateChange(for: mockPeripheralManager)
        #expect(mockPeripheralManager.didRemoveService)
    }
    
    @Test("When bluetooth turns on, add new service")
    func addNewServiceOnBluetoothTurnedOn() {
        MockPeripheralManager.authorization = .allowedAlways
        sut?.handleStateChange(for: mockPeripheralManager)
        #expect(mockPeripheralManager.addedService != nil)
    }
    
    @Test("Starts advertising when bluetooth is powered on")
    func startsAdvertisingWhenPoweredOn() {
        MockPeripheralManager.authorization = .allowedAlways
        sut?.handleStateChange(for: mockPeripheralManager)
        #expect(peripheralManager.isAdvertising)
    }
    
    @Test("Successfully starts advertising the added service")
    func successfullyInitiatesAdvertising() {
        MockPeripheralManager.authorization = .allowedAlways
        sut?.handleStateChange(for: mockPeripheralManager)
        
        #expect(mockPeripheralManager.delegate === sut)
        #expect(peripheralManager.advertisedServiceID == sut?.serviceCBUUID)
        #expect(peripheralManager.isAdvertising == true)
    }
    
    @Test("handleDidAddService does not call delegate method when error passed")
    func addServiceDoesNotCallDelegateMethodWhenErrorPassed() {
        let service = CBMutableService(type: sut!.serviceCBUUID, primary: true)
        sut?.handle(mockPeripheralManager, didAdd: service, error: PeripheralError.addServiceError(""))
        
        #expect(mockDelegate.didUpdateState == false)
    }
    
    @Test("handleDidStartAdvertising calls delegate method")
    func callsDelegateMethod() {
        sut?.handleDidStartAdvertising(mockPeripheralManager, error: nil)
        
        #expect(mockDelegate.didUpdateState == true)
    }
    
    @Test("handleDidStartAdvertising does not call delegate method when error passed")
    func doesNotCallDelegateMethodWhenErrorPassed() {
        sut?.handleDidStartAdvertising(mockPeripheralManager, error: PeripheralError.startAdvertisingError(""))
        
        #expect(mockDelegate.didUpdateState == false)
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
            sut?.handleStateChange(for: mockPeripheralManager)
            
            #expect(mockPeripheralManager.isAdvertising == false)
        }
    }
    
    @Test("Does not advertise when permissions not granted")
    func doesNotStartAdvertisingWhenPermissionsNotGranted() {
        for auth in [CBManagerAuthorization.notDetermined, .restricted, .denied] {
            MockPeripheralManager.authorization = auth
            sut?.handleStateChange(for: peripheralManager)
            
            #expect(mockPeripheralManager.isAdvertising == false)
        }
    }
    
    @Test("Stores subscribed central")
    func storesSubscribedCentral() throws {
        #expect(sut?.subscribedCentrals.isEmpty ?? false)
        let characteristic = try #require(characteristics.first)

        sut?.handle(central: MockCentral(), didSubscribeTo: characteristic)
        
        #expect(sut?.subscribedCentrals.count == 1)
    }
    
    @Test("Stored central contains subscribed characteristic")
    func storedCentralContainsSubscribedCharacteristic() throws {
        let characteristic = try #require(characteristics.first)
        
        sut?.handle(central: MockCentral(), didSubscribeTo: characteristic)
        
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
        sut?.handle(central: central, didSubscribeTo: characteristic)
        sut?.handle(central: central, didSubscribeTo: characteristic)
        
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
            case .notPoweredOn:
                #expect(
                    error.errorDescription == "Bluetooth is not ready. Current state: \(error.poweredOnState!)."
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
    
    @Test("Did receive write request start value to State characteristic")
    func receivesWriteRequestForStartToState() {
        let request = MockATTRequest(
            characteristic: characteristics
                .first(
                    where: { $0.uuid == CBUUID(
                        string: CharacteristicType.state.rawValue
                    )
                    })!
        )
        sut?.handle(mockPeripheralManager, didReceiveWrite: [request])
        
        
    }
}

class MockATTRequest: ATTRequestProtocol {
    var characteristic: CBCharacteristic
        
    var value: Data?
    
    init(characteristic: CBCharacteristic, value: Data? = nil) {
        self.characteristic = characteristic
        self.value = value
    }
}
