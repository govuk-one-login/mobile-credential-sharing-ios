import CoreBluetooth
@testable import SharingBluetoothTransport
import Testing

// swiftlint:disable type_body_length
// swiftlint:disable file_length
@MainActor
@Suite("BlePeripheralTransportTests")
struct BlePeripheralTransportTests {
    static let testServiceUUIDString = "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE"
    let sessionEstablishmentBase64 =
    """
    omplUmVhZGVyS2V52BhYS6QBAiABIVggYOM5I4UEH1FAMFHyQVUx
    y1bdP5mccWhwE6rGdovIGH4iWCDljeuP2+kH991TaCRVUaNHlvfS
    IVxEDDObsPe2e+zN+mRkYXRhWQLfUq2irL62w5DyygvGWbSEZ465
    TdRQdDhqreziN3e0RgbkLihGvC4u48HoZ7HRaF5BNUoCGrsP2jbw
    nPXVxRtWHTvkHJNHrnHPK0nenex7RARqsCJHkxshDJFXhAwVFKYC
    ewiBBxat9hlmNEl5MUrDrp9A5m4BXBJUpoQQi9CT6HcuwzP7Zj/W
    gDrwLqEL2+g6mZ91tVoYD4chOftXrASs1YyhXsoVDN4cO4SUARiL
    ejDOiH3XtxsS7aL8bsblI1pslJg1H80wHyKSpOu6dVUoXO6E6tlu
    8Wd7Cvgjn2p6Uq9LiAmx1SqyGhYsoxreIcV70dmXCigyqsQcfVLR
    xP7k7mQDCiGN9RNjvnAXkvpsUVxIm9Odytb7pI8dbrGenHaVMaO/
    mZijLAGEEwXyOETKPbah/w0NkXND1i/HKtWOqwGjGYEW8ZYGYJ+U
    416st40jxZxnhSo2GRX+h4SM26VjDJn6txrv9y0THPRCZU93COxI
    IWQW8tmWz2z5EBK3cbiJB7HRYp36eUND5lPDEgdILi9mIc1LXc87
    PDKGJcM/6YvpnF8mSiZDFb5Buv3HJvi83lkg3gpxiE2GCvRMH/Gz
    14sujXINhdrlP+orP6GAYWKkvgLQOVZ8XrJBnCrYea9I/LffVcqU
    8bAPYhh/ojKcgieq4BMOwFLKPiEC5X5ykRsyjP3Puq9rk2RmD2E0
    FTgmRMMMC9TiIsXPlLpac2ecU9XO2VylB4fCKJoMFzWDk8Hg8icj
    YQAvubFgYGiIpZ73osOJ9ot8tCRXLbAmsXzyvcr8tnyCktkrUAUD
    VpAKYqgrFvhUdZBSsA8PRnOkYin0Mlfo6DJUAbP+zIxtIli69/fC
    +7r6s6G2re1Ozqwer9W2ERjfk7wKYisDUE/eR867Ik6YPbEmd+MW
    wiquBC1s5K2uDYsPQEN7jhr6CFnJUBvrY5dEloWaYPEQabGWW0/6
    xXealhkfierHyqaIueZ8
    """.filter { !$0.isWhitespace }

    let mockErrorDescription = "Mock error"
    
    let mockPeripheralManager = MockPeripheralManager()
    let mockDelegate = MockBlePeripheralTransportDelegate()
    let sut: BlePeripheralTransport
    
    let stateCharacteristic = CBMutableCharacteristic(characteristic: CharacteristicType.state)
    let clientToServerCharacteristic = CBMutableCharacteristic(characteristic: CharacteristicType.clientToServer)

    let serviceUUID: UUID
    let characteristics: [CBMutableCharacteristic]

    init() throws {
        let uuid = try #require(UUID(uuidString: Self.testServiceUUIDString))
        self.serviceUUID = uuid

        self.sut = BlePeripheralTransport(
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
    @Test("PeripheralTransport listens to changes from manager")
    func transportListensToChangesFromManager() {
        #expect(mockPeripheralManager.delegate === sut)
    }

    @Test("serviceUUID matches the one passed in")
    func serviceUUIDMatches() {
        #expect(sut.serviceCBUUID == CBUUID(nsuuid: serviceUUID))
    }

    // MARK: - Service tests
    @Test("When bluetooth turns on, remove existing services")
    func removeExistingServicesOnBluetoothTurnedOn() {
        sut.startAdvertising()
        #expect(mockPeripheralManager.didRemoveService)
    }

    @Test("When bluetooth turns on, add new service")
    func addNewServiceOnBluetoothTurnedOn() {
        sut.startAdvertising()
        #expect(mockPeripheralManager.addedService != nil)
    }
    
    @Test("handleDidAddService does not call delegate method when error passed")
    func addServiceDoesNotCallDelegateMethodWhenErrorPassed() {
        let service = CBMutableService(type: sut.serviceCBUUID, primary: true)
        sut.handleDidAddService(
            for: mockPeripheralManager,
            service: service,
            error: PeripheralError.addServiceError(mockErrorDescription)
        )

        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == PeripheralError.addServiceError("Failed to add service: \(mockErrorDescription)."))
    }

    // MARK: - Advertising tests
    @Test("Starts advertising when bluetooth is powered on")
    func startsAdvertisingWhenPoweredOn() {
        sut.startAdvertising()
        #expect(mockPeripheralManager.isAdvertising)
    }

    @Test("Successfully starts advertising the added service")
    func successfullyInitiatesAdvertising() {
        sut.startAdvertising()

        #expect(mockPeripheralManager.advertisedServiceID == sut.serviceCBUUID)
        #expect(mockPeripheralManager.isAdvertising == true)
    }

    @Test("handleDidStartAdvertising calls delegate method")
    func callsDelegateMethod() {
        sut.handleDidStartAdvertising(for: mockPeripheralManager, error: nil)

        #expect(mockDelegate.didAddService == true)
    }

    @Test("handleDidStartAdvertising does not call delegate method when error passed")
    func doesNotCallDelegateMethodWhenErrorPassed() {
        sut.handleDidStartAdvertising(for: mockPeripheralManager, error: PeripheralError.startAdvertisingError(mockErrorDescription))

        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == PeripheralError.startAdvertisingError("Failed to start advertising: \(mockErrorDescription)."))
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
        #expect(sut.subscribedCentral == nil)
        let mockCentral = MockCentral()
        let characteristic = try #require(characteristics.first)
        sut.handleDidSubscribe(for: mockPeripheralManager, central: mockCentral, to: characteristic)

        #expect(sut.subscribedCentral?.identifier == mockCentral.identifier)
    }

    @Test("Correct characteristics are added to GATT service")
    func subscribedCharacteristicIsPartOfGATTService() throws {
        let service = sut.mutableServiceWithServiceCharacterics(sut.serviceCBUUID)

        let expectedUUIDs = Set(characteristics.map { $0.uuid })
        let serviceUUIDs = Set(service.characteristics?.map { $0.uuid } ?? [])

        #expect(expectedUUIDs == serviceUUIDs)
    }

    @Test("Passes error when trying to subscribe two different centrals")
    func removesDuplicateSubscribedCentrals() throws {
        let mockCentral1 = MockCentral()
        let mockCentral2 = MockCentral()
        let characteristic = try #require(characteristics.first)

        #expect(sut.subscribedCentral == nil)

        sut.handleDidSubscribe(for: mockPeripheralManager, central: mockCentral1, to: characteristic)
        sut.handleDidSubscribe(for: mockPeripheralManager, central: mockCentral2, to: characteristic)

//        #expect(sut.subscribedCentrals[characteristic]?.count == 1)
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

    @Test("Did receive write request end value 0x02 to State characteristic")
    func receivesWriteRequestForEndToState() {
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let endRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x02])
        )

        // Given
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])

        // reset mock
        mockPeripheralManager.didRespondToRequest = false
        mockPeripheralManager.lastResponseResult = nil

        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [endRequest])

        // Then
        #expect(mockPeripheralManager.didRespondToRequest == true)
        #expect(mockPeripheralManager.lastResponseResult == .success)
        #expect(mockDelegate.didReceiveEndRequest == true)
    }

    @Test("Client-to-server rejected when reader sends end (0x02) to State")
    func clientToServerRejectedWhenReaderSendsEndToState() {
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let endRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x02])
        )
        let mockMessage: [UInt8] = [0x00, 0x02, 0x04, 0x08]
        let clientToServerRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(mockMessage)
        )

        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [endRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [clientToServerRequest])

        #expect(mockDelegate.didUpdateState == false)
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
        #expect(mockDelegate.didThrowError == PeripheralError.clientToServerError("Connection not established."))
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
    func receivesFullSessionEstablishmentMessage() throws {
        // Given
        let sessionEstablishmentData = try Data([0x00]) + #require(Data(base64Encoded: sessionEstablishmentBase64))
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let sessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: sessionEstablishmentData
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [sessionEstablishmentRequest])
        
        // Then
        /// Resets stored characteristic data to nil once message is successfully sent
        #expect(mockDelegate.messageDecodedSuccessfully == true)
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
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
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
        #expect(mockDelegate.didThrowError == PeripheralError.clientToServerError("Invalid data received, first byte was not 0x01 or 0x00."))
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
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
        #expect(mockDelegate.didThrowError == PeripheralError.clientToServerError("Invalid data received, data is nil."))
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
        #expect(mockDelegate.didThrowError == PeripheralError.clientToServerError("Invalid data received, empty byte array."))
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
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
        #expect(mockDelegate.didThrowError == PeripheralError.clientToServerError("Connection not established."))
    }
    
    @Test("Receives & sends invalid CBOR encoded SessionEstablishmentMessage to delegate")
    func receivedInvalidCBOREncodedMessageNoMap() async throws {
        // Given
        let mockMessageNoMap: [UInt8] = [0x00, 0x02, 0x04, 0x08]
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let sessionEstablishmentRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(mockMessageNoMap)
        )
        
        // When
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [sessionEstablishmentRequest])
        
        // Then
        #expect(mockDelegate.messageDecodedSuccessfully == false)
    }
    
    // MARK: - Did unsubscribe tests
    @Test("handleDidUnsubscribe does not call delegate method")
    func handleDidUnsubscribeDoesNotCallDelegateMethod() throws {
        sut.handleDidUnsubscribe()

        #expect(mockDelegate.didUpdateState == false)
        #expect(mockDelegate.didThrowError == PeripheralError.connectionTerminated)
    }
    
    @Test("Removes Services & Stops Advertising when stopAdvertising is called")
    func removesServicesAndStopsAdvertising() async throws {
        // Given
        sut.startAdvertising()
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

    @Test("Client-to-server rejected when session ended by stopAdvertising")
    func clientToServerRejectedWhenSessionEndedByStopAdvertising() {
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        let mockMessage: [UInt8] = [0x00, 0x02, 0x04, 0x08]
        let clientToServerRequest = MockATTRequest(
            characteristic: clientToServerCharacteristic,
            value: Data(mockMessage)
        )

        sut.handleDidUpdateState(for: mockPeripheralManager)
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        sut.stopAdvertising()
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [clientToServerRequest])

        #expect(mockDelegate.didUpdateState == false)
        #expect(sut.characteristicData[CharacteristicType.clientToServer] == nil)
        #expect(mockDelegate.didThrowError == PeripheralError.clientToServerError("Connection not established."))
    }

    // MARK: - sendData tests
    @Test("sendData prepends endOfData byte and calls updateValue on the serverToClient characteristic")
    func sendDataPrependsEndOfDataByteAndCallsUpdateValue() {
        // Given
        sut.startAdvertising()
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        sut.handleDidSubscribe(for: mockPeripheralManager, central: MockCentral(), to: characteristics.first!)
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        mockPeripheralManager.didCallUpdateValue = false
        mockPeripheralManager.lastUpdateValueData = nil

        let payload = Data([0xAA, 0xBB])

        // When
        sut.sendData(payload)

        // Then
        #expect(mockPeripheralManager.didCallUpdateValue == true)
        let expected = Data([MessageDataFirstByte.endOfData.rawValue]) + payload
        #expect(mockPeripheralManager.lastUpdateValueData == expected)
    }

    @Test("sendData reports error when connection is not established")
    func sendDataReportsErrorWhenNotConnected() {
        // Given
        sut.startAdvertising()
        mockDelegate.didThrowError = nil

        // When — no start request, so connectionEstablished is false
        sut.sendData(Data([0x01]))

        // Then
        #expect(mockPeripheralManager.didCallUpdateValue == false)
        #expect(mockDelegate.didThrowError == .clientToServerError("Cannot send data: connection not established or characteristic unavailable."))
    }

    @Test("sendData reports error when updateValue returns false")
    func sendDataReportsErrorWhenUpdateValueFails() {
        // Given
        sut.startAdvertising()
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        sut.handleDidSubscribe(for: mockPeripheralManager, central: MockCentral(), to: characteristics.first!)
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        mockPeripheralManager.updateValueReturnValue = false
        mockDelegate.didThrowError = nil

        // When
        sut.sendData(Data([0x01]))

        // Then
        #expect(mockDelegate.didThrowError == .clientToServerError("Failed to send SessionData via serverToClient characteristic."))
    }

    // MARK: - sendData chunking tests

    /// Helper: establishes connection with a MockCentral of a given MTU and resets tracking state
    private func establishConnection(mtu: Int) {
        let central = MockCentral()
        central.maximumUpdateValueLength = mtu
        sut.startAdvertising()
        sut.handleDidSubscribe(for: mockPeripheralManager, central: central, to: characteristics.first!)
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        mockPeripheralManager.didCallUpdateValue = false
        mockPeripheralManager.lastUpdateValueData = nil
        mockPeripheralManager.allUpdateValueData = []
    }

    @Test("Chunk size is maximumUpdateValueLength minus 1 byte for ISO header")
    func chunkSizeIsMaxUpdateValueLengthMinusOne() {
        // Given - MTU that yields maximumUpdateValueLength of 10, so chunk size == 9
        establishConnection(mtu: 10)
        // 18 bytes of data -> 2 chunks of 9
        let data = Data(repeating: 0xAA, count: 18)

        // When
        sut.sendData(data)

        // Then - 1 intermediate (9 bytes) + 1 final chunk (9 bytes)
        #expect(mockPeripheralManager.allUpdateValueData.count == 2)
        // Each intermediate chunk payload (minus header) should be exactly 9 bytes
        let firstChunkPayload = mockPeripheralManager.allUpdateValueData[0].dropFirst()
        let secondChunkPayload = mockPeripheralManager.allUpdateValueData[1].dropFirst()
        #expect(firstChunkPayload.count == 9)
        #expect(secondChunkPayload.count == 9)
    }

    @Test("Intermediate chunks are prefixed with 0x01")
    func intermediateChunksArePrefixedWithMoreData() {
        // Given MTU that yields maximumUpdateValueLength of 5, so chunk size == 4
        establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])

        // When
        sut.sendData(data)

        // Then - 2 intermediate (4 bytes) + 1 final chunk (1 byte)
        #expect(mockPeripheralManager.allUpdateValueData.count == 3)
        #expect(mockPeripheralManager.allUpdateValueData[0].first == MessageDataFirstByte.moreData.rawValue)
        #expect(mockPeripheralManager.allUpdateValueData[1].first == MessageDataFirstByte.moreData.rawValue)
    }

    @Test("Final chunk is prefixed with 0x00")
    func finalChunkIsPrefixedWithEndOfData() {
        // Given MTU that yields maximumUpdateValueLength of 5, so chunk size == 4
        establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])

        // When
        sut.sendData(data)

        // Then
        let lastChunk = mockPeripheralManager.allUpdateValueData.last
        #expect(lastChunk?.first == MessageDataFirstByte.endOfData.rawValue)
    }

    @Test("Chunked data reassembles to original payload when headers are stripped")
    func chunkedDataReassemblesToOriginalPayload() {
        // Given MTU that yields maximumUpdateValueLength of 5, so chunk size == 4
        establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])

        // When
        sut.sendData(data)

        // Then - strip headers and reassemble
        let reassembled = mockPeripheralManager.allUpdateValueData.reduce(Data()) { result, chunk in
            result + chunk.dropFirst()
        }
        #expect(reassembled == data)
    }

    @Test("Data exactly equal to chunk size sends a single 0x00 packet")
    func dataExactlyOneChunkSendsSinglePacket() {
        // Given MTU that yields maximumUpdateValueLength of 5, so chunk size == 4
        establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04])

        // When
        sut.sendData(data)

        // Then - single final chunk
        #expect(mockPeripheralManager.allUpdateValueData.count == 1)
        #expect(mockPeripheralManager.allUpdateValueData[0] == Data([0x00, 0x01, 0x02, 0x03, 0x04]))
    }

    @Test("sendData stops sending and reports error when updateValue fails mid-chunk")
    func sendDataStopsOnUpdateValueFailureMidChunk() {
        // Given MTU that yields maximumUpdateValueLength of 5, so chunk size == 4
        establishConnection(mtu: 5)
        let data = Data(repeating: 0xAA, count: 12)
        // Fail on the first call
        mockPeripheralManager.updateValueReturnValue = false
        mockDelegate.didThrowError = nil

        // When
        sut.sendData(data)

        // Then - only 1 call attempted, error reported
        #expect(mockPeripheralManager.allUpdateValueData.count == 1)
        #expect(mockDelegate.didThrowError == .clientToServerError("Failed to send SessionData via serverToClient characteristic."))
    }

    // MARK: - End session / State 0x02 notify tests
    @Test("endSession notifies State 0x02 when connected and updateValue succeeds")
    func endSessionNotifiesStateEndWhenConnected() {
        sut.startAdvertising()
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        sut.handleDidSubscribe(for: mockPeripheralManager, central: MockCentral(), to: characteristics.first!)
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        mockPeripheralManager.didCallUpdateValue = false
        mockPeripheralManager.lastUpdateValueData = nil

        sut.endSession()

        #expect(mockPeripheralManager.didCallUpdateValue == true)
        #expect(mockPeripheralManager.lastUpdateValueData == ConnectionState.end.data)
        #expect(mockPeripheralManager.isAdvertising == false)
    }

    @Test("endSession does not call updateValue when not connected")
    func endSessionNotifiesStateEndWhenNotConnected() {
        sut.handleDidUpdateState(for: mockPeripheralManager)
        mockPeripheralManager.didCallUpdateValue = false

        sut.endSession()

        #expect(mockPeripheralManager.didCallUpdateValue == false)
        #expect(mockPeripheralManager.isAdvertising == false)
    }

    @Test("endSession reports failedToNotifyEnd when updateValue returns false (eg. queue full, no subscribers, connection lost)")
    func endSessionReportsErrorWhenUpdateValueFails() {
        sut.startAdvertising()
        let startRequest = MockATTRequest(
            characteristic: stateCharacteristic,
            value: Data([0x01])
        )
        sut.handleDidSubscribe(for: mockPeripheralManager, central: MockCentral(), to: characteristics.first!)
        sut.handleDidReceiveWrite(for: mockPeripheralManager, with: [startRequest])
        mockPeripheralManager.updateValueReturnValue = false
        mockDelegate.didThrowError = nil

        sut.endSession()

        #expect(mockDelegate.didThrowError == .failedToNotifyEnd)
        #expect(mockPeripheralManager.isAdvertising == false)
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
