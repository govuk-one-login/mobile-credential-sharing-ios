import CoreBluetooth
import Testing

@testable import Bluetooth

// swiftlint:disable type_body_length
@MainActor
@Suite("PeripheralSessionTests")
struct PeripheralSessionTests {
    static let testServiceUUIDString = "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE"

    let mockPeripheralManager = MockPeripheralManager()
    let mockDelegate = MockPeripheralSessionDelegate()
    let sut: PeripheralSession
    
    let stateCharacteristic = CBMutableCharacteristic(characteristic: CharacteristicType.state)
    let clientToServerCharacteristic = CBMutableCharacteristic(characteristic: CharacteristicType.clientToServer)

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

    // MARK: - Initialisation tests
    @Test("Session listens to changes from manager")
    func sessionListensToChangesFromManager() {
        #expect(mockPeripheralManager.delegate === sut)
    }

    @Test("serviceUUID matches the one passed in")
    func serviceUUIDMatches() {
        #expect(sut.serviceCBUUID == CBUUID(nsuuid: serviceUUID))
    }

    // MARK: - Service tests
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
    
    @Test("handleDidAddService does not call delegate method when error passed")
    func addServiceDoesNotCallDelegateMethodWhenErrorPassed() {
        let service = CBMutableService(type: sut.serviceCBUUID, primary: true)
        sut.handleDidAddService(
            for: mockPeripheralManager,
            service: service,
            error: PeripheralError.addServiceError("")
        )

        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == true)
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

    // MARK: - Advertising tests
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

    @Test("handleDidStartAdvertising calls delegate method")
    func callsDelegateMethod() {
        sut.handleDidStartAdvertising(for: mockPeripheralManager, error: nil)

        #expect(mockDelegate.didUpdateState == true)
    }

    @Test("handleDidStartAdvertising does not call delegate method when error passed")
    func doesNotCallDelegateMethodWhenErrorPassed() {
        sut.handleDidStartAdvertising(for: mockPeripheralManager, error: PeripheralError.startAdvertisingError(""))

        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == true)
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

    // MARK: - Characteristic Tests
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

    // MARK: - Receives write request tests
    @Test("Did receive write request start value to State characteristic")
    func receivesWriteRequestForStartToState() {
        let request = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )

        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [request])

        #expect(mockPeripheralManager.didRespondToRequest == true)
        #expect(mockPeripheralManager.lastResponseResult == .success)
    }
    
    @Test("Did receive partial SessionEstablishment message")
    func receivesPartialSessionEstablishmentMessage() {
        // Given
        let mockMessage: [UInt8] = [0x01, 0x02, 0x04, 0x08]
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let partialSessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(mockMessage)
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [partialSessionEstablishmentRequest])
        
        // Then
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == Data(mockMessage.dropFirst()))
    }
    
    @Test("Did receive full SessionEstablishment message")
    func receivesFullSessionEstablishmentMessage() {
        // Given
        let firstMockMessage: [UInt8] = [0x01, 0x02, 0x04, 0x08]
        let secondMockMessage: [UInt8] = [0x00, 0x20, 0x40, 0x00]
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let firstSessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(firstMockMessage)
        )
        let secondSessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(secondMockMessage)
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [firstSessionEstablishmentRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [secondSessionEstablishmentRequest])
        
        // Then
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == Data(firstMockMessage.dropFirst() + secondMockMessage.dropFirst()))
    }
    
    @Test("Recieved invalid first byte for SessionEstablishmentMessage")
    func receivedInvalidFirstByte() async throws {
        // Given
        let invalidMockMessage: [UInt8] = [0x03, 0x02, 0x04, 0x08]
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let invalidSessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(invalidMockMessage)
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [invalidSessionEstablishmentRequest])
        
        // Then
        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == true)
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
    }
    
    @Test("Recieved no data for SessionEstablishmentMessage")
    func receivedInvalidData() async throws {
        // Given
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let invalidSessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: nil
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [invalidSessionEstablishmentRequest])
        
        // Then
        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == true)
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
    }
    
    @Test("Recieved empty data for SessionEstablishmentMessage")
    func receivedEmptyData() async throws {
        // Given
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let invalidSessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data()
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [invalidSessionEstablishmentRequest])
        
        // Then
        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == true)
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
    }
    
    @Test("Recieved SessionEstablishmentMessage when State connection not established")
    func stateConnectionNotEstablished() async throws {
        // Given
        let mockMessage: [UInt8] = [0x00, 0x02, 0x04, 0x08]
        let sessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(mockMessage)
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [sessionEstablishmentRequest])
        
        // Then
        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == true)
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
    }
    
    // MARK: - Did unsubscribe tests
    @Test("handleDidUnsubscribe does not call delegate method")
    func handleDidUnsubscribeDoesNotCallDelegateMethod() throws {
        sut.handleDidUnsubscribe()

        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == true)
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
// swiftlint:enable type_body_length
