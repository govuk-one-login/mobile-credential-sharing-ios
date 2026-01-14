import CoreBluetooth
import Testing

@testable import Bluetooth

@MainActor
@Suite("PeripheralSessionTests")
struct PeripheralSessionTests {
    static let testServiceUUIDString = "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE"

    let mockPeripheralManager = MockPeripheralManager()
    let mockDelegate = MockPeripheralSessionDelegate()
    let sut: PeripheralSession

    let serviceUUID: UUID
    let characteristics: [CBMutableCharacteristic]

    init() throws {
        let uuid = try #require(UUID(uuidString: Self.testServiceUUIDString))
        self.serviceUUID = uuid

        self.sut = PeripheralSession(
            peripheralManager: mockPeripheralManager,
            serviceUUID: uuid
        )

        sut.delegate = mockDelegate

        self.characteristics = CharacteristicType.allCases.compactMap {
            CBMutableCharacteristic(characteristic: $0)
        }

        // Ensure mock state is ready for testing
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
        sut.handleDidUpdateState(for: mockPeripheralManager)
        #expect(mockPeripheralManager.addedService != nil)
    }

    @Test("Starts advertising when bluetooth is powered on")
    func startsAdvertisingWhenPoweredOn() {
        sut.handleDidUpdateState(for: mockPeripheralManager)
        #expect(mockPeripheralManager.isAdvertising)
    }

    @Test("Successfully starts advertising the added service")
    func successfullyInitiatesAdvertising() {
        sut.handleDidUpdateState(for: mockPeripheralManager)

        #expect(mockPeripheralManager.advertisedServiceID == sut.serviceCBUUID)
        #expect(mockPeripheralManager.isAdvertising == true)
    }

    @Test("handleDidAddService does not call delegate method when error passed")
    func addServiceDoesNotCallDelegateMethodWhenErrorPassed() {
        let service = CBMutableService(type: sut.serviceCBUUID, primary: true)
        sut.handleDidAddService(
            for: mockPeripheralManager,
            service: service,
            error: PeripheralError.addServiceError("")
        )

        #expect(mockDelegate.didUpdateState == false)
    }

    @Test("handleDidAddService calls delegate method when no error passed")
    func addServiceCallsDelegateMethodWhenNoException() {
        let service = CBMutableService(type: sut.serviceCBUUID, primary: true)

        sut.handleDidAddService(
            for: mockPeripheralManager,
            service: service,
            error: nil  // Explicitly pass nil for success
        )

        #expect(mockDelegate.didUpdateState == true)
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

    @Test(
        "Does not advertise when bluetooth is not ready",
        arguments: [
            CBManagerState.unknown, .resetting, .unauthorized, .unsupported, .poweredOff
        ]
    )
    func doesNotStartAdvertisingWhenNotReady(state: CBManagerState) {
        mockPeripheralManager.state = state
        sut.handleDidUpdateState(for: mockPeripheralManager)

        #expect(mockPeripheralManager.isAdvertising == false)
    }

    @Test(
        "Does not advertise when permissions not granted",
        arguments: [
            CBManagerAuthorization.notDetermined,
            CBManagerAuthorization.restricted,
            CBManagerAuthorization.denied
        ]
    )
    func doesNotStartAdvertisingWhenPermissionsNotGranted(auth: CBManagerAuthorization) {
        mockPeripheralManager.authorization = auth
        mockPeripheralManager.isAdvertising = false  // Reset state for each iteration
        sut.handleDidUpdateState(for: mockPeripheralManager)

        #expect(mockPeripheralManager.isAdvertising == false)
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
            .sessionEstablishmentError("session"),
            .connectionTerminated,
            .unknown
        ] {
            switch error {
            case .notPoweredOn:
                #expect(
                    error.errorDescription == "Bluetooth is not ready. Current state: \(error.poweredOnState!)."
                )
            case .permissionsNotGranted:
                #expect(
                    error.errorDescription
                        == "App does not have the required Bluetooth permissions. Current state: \(error.permissionState!)."
                )
            case .addServiceError(let description):
                #expect(
                    error.errorDescription == "Failed to add service: \(description)."
                )
            case .startAdvertisingError(let description):
                #expect(
                    error.errorDescription == "Failed to start advertising: \(description)."
                )
            case .sessionEstablishmentError(let description):
                #expect(
                    error.errorDescription == "Session establishment failed: \(description)."
                )
            case .connectionTerminated:
                #expect(error.errorDescription == "Bluetooth disconnected unexpectedly.")
            case .unknown:
                #expect(error.errorDescription == "An unknown error has occured.")
            }
        }
    }

    @Test("Did receive write request start value to State characteristic")
    func receivesWriteRequestForStartToState() {
        let stateCharacteristic = CBMutableCharacteristic(characteristic: CharacteristicType.state)

        let request = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )

        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [request])

        #expect(mockPeripheralManager.didRespondToRequest == true)
        #expect(mockPeripheralManager.lastResponseResult == .success)
    }
    
    @Test("handleDidUnsubscribe does not call delegate method")
    func handleDidUnsubscribeDoesNotCallDelegateMethod() throws {
        sut.handleDidUnsubscribe()

        #expect(mockDelegate.didUpdateState == false)
    }
    
    @Test("Removes Services & Stops Advertising when stopAdvertising is called")
    func removesServicesAndStopsAdvertising() async throws {
        // Given
        sut.handleDidUpdateState(for: mockPeripheralManager)
        let characteristic = try #require(characteristics.first)
        sut.handleDidSubscribe(for: mockPeripheralManager, central: MockCentral(), to: characteristic)
        #expect(mockPeripheralManager.addedService != nil)
        #expect(mockPeripheralManager.isAdvertising == true)
        
        // When
        sut.stopAdvertising()
        
        // Then
        #expect(mockPeripheralManager.didRemoveService == true)
        #expect(mockPeripheralManager.addedService == nil)
        #expect(mockPeripheralManager.isAdvertising == false)
    }
}
