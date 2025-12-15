@testable import Bluetooth
import CoreBluetooth
import Testing

@MainActor
@Suite("PeripheralSessionTests")
struct PeripheralSessionTests {
    let mockPeripheralManager = MockPeripheralManager()
    let mockDelegate = MockPeripheralSessionDelegate()
    
    let sut: PeripheralSession
    let serviceUUID: UUID = UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID()
    let characteristics: [CBMutableCharacteristic]
    
    init() {
        self.sut = PeripheralSession(
            peripheralManager: mockPeripheralManager,
            serviceUUID: UUID(uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE") ?? UUID()
        )
        sut.delegate = mockDelegate
        self.characteristics = CharacteristicType.allCases.compactMap(
            { CBMutableCharacteristic(characteristic: $0) }
        )
        mockPeripheralManager.authorization = .allowedAlways
    }
    
    @Test("Session listens to changes from manager")
    func sessionListensToChangesFromManager() {
        #expect(mockPeripheralManager.delegate === sut)
    }
    
    @Test("serviceUUID matches the one passed in")
    func serviceUUIDMatches() {
        #expect(sut.serviceCBUUID == CBUUID(nsuuid: serviceUUID))
    }
    
    @Test("When bluetooth turns on, remove existing services")
    func removeExistingServicesOnBluetoothTurnedOn() {
        sut.handleDidUpdateState(for: mockPeripheralManager)
        #expect(mockPeripheralManager.didRemoveService)
    }
    
    @Test("When bluetooth turns on, add new service")
    func addNewServiceOnBluetoothTurnedOn() {
        mockPeripheralManager.authorization = .allowedAlways
        sut.handleDidUpdateState(for: mockPeripheralManager)
        #expect(mockPeripheralManager.addedService != nil)
    }
    
    @Test("Starts advertising when bluetooth is powered on")
    func startsAdvertisingWhenPoweredOn() {
        mockPeripheralManager.authorization = .allowedAlways
        sut.handleDidUpdateState(for: mockPeripheralManager)
        #expect(mockPeripheralManager.isAdvertising)
    }
    
    @Test("Successfully starts advertising the added service")
    func successfullyInitiatesAdvertising() {
        mockPeripheralManager.authorization = .allowedAlways
        sut.handleDidUpdateState(for: mockPeripheralManager)
        
        #expect(mockPeripheralManager.delegate === sut)
        #expect(mockPeripheralManager.advertisedServiceID == sut.serviceCBUUID)
        #expect(mockPeripheralManager.isAdvertising == true)
    }
    
    @Test("handleDidAddService does not call delegate method when error passed")
    func addServiceDoesNotCallDelegateMethodWhenErrorPassed() {
        let service = CBMutableService(type: sut.serviceCBUUID, primary: true)
        sut.handleDidAddService(for: mockPeripheralManager, service: service, error: PeripheralError.addServiceError(""))
        
        #expect(mockDelegate.didUpdateState == false)
    }
    
    @Test("handleDidStartAdvertising calls delegate method")
    func callsDelegateMethod() {
        sut.handleDidStartAdvertising(for: mockPeripheralManager, error: nil)
        
        #expect(mockDelegate.didUpdateState == true)
    }
    
    @Test("handleDidStartAdvertising does not call delegate method when error passed")
    func doesNotCallDelegateMethodWhenErrorPassed() {
        sut.handleDidStartAdvertising(for: mockPeripheralManager, error: PeripheralError.startAdvertisingError(""))
        
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
            sut.handleDidUpdateState(for: mockPeripheralManager)
            
            #expect(mockPeripheralManager.isAdvertising == false)
        }
    }
    
    @Test("Does not advertise when permissions not granted")
    func doesNotStartAdvertisingWhenPermissionsNotGranted() {
        for auth in [CBManagerAuthorization.notDetermined, .restricted, .denied] {
            mockPeripheralManager.authorization = auth
            mockPeripheralManager.isAdvertising = false
            sut.handleDidUpdateState(for: mockPeripheralManager)
            
            #expect(mockPeripheralManager.isAdvertising == false)
        }
    }
    
    @Test("Stores subscribed central")
    func storesSubscribedCentral() throws {
        #expect(sut.subscribedCentrals.isEmpty)
        let characteristic = try #require(characteristics.first)
        sut.handleDidSubscribe(for: mockPeripheralManager, central: MockCentral(), to: characteristic)
        
        #expect(sut.subscribedCentrals.count == 1)
    }
    
    @Test("Stored central contains subscribed characteristic")
    func storedCentralContainsSubscribedCharacteristic() throws {
        let characteristic = try #require(characteristics.first)
        sut.handleDidSubscribe(for: mockPeripheralManager, central: MockCentral(), to: characteristic)
        
        #expect(sut.subscribedCentrals.first?.key == characteristic)
    }
    
    @Test("Correct characteristics are added to GATT service")
    func subscribedCharacteristicIsPartOfGATTService() throws {
        let service = sut.mutableServiceWithServiceCharacterics(sut.serviceCBUUID)
        
        let expectedUUIDs = Set(characteristics.map { $0.uuid })
        let serviceUUIDs = Set(service.characteristics?.map { $0.uuid } ?? [])
        
        #expect(expectedUUIDs == serviceUUIDs)
    }
        
    @Test("Removes duplicate subscribed centrals")
    func removesDuplicateSubscribedCentrals() throws {
        let central = MockCentral()
        let characteristic = try #require(characteristics.first)
        
        #expect(sut.subscribedCentrals.count == 0)
        
        sut.handleDidSubscribe(for: mockPeripheralManager, central: central, to: characteristic)
        sut.handleDidSubscribe(for: mockPeripheralManager, central: central, to: characteristic)
        
        #expect(sut.subscribedCentrals[characteristic]?.count == 1)
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
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [request])
    }
}


