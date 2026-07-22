import CoreBluetooth
@testable import SharingBluetoothTransport
import Testing

// swiftlint:disable file_length
@Suite("BleCentralTransportTests")
// swiftlint:disable:next type_body_length
struct BleCentralTransportTests {
    let mockCentralManager = MockCBCentralManager()
    let mockDelegate = MockBleCentralTransportDelegate()
    let serviceUUID = UUID()
    let sut: BleCentralTransport

    init() {
        sut = BleCentralTransport(
            centralManager: mockCentralManager,
            serviceUUID: serviceUUID
        )
        sut.delegate = mockDelegate
    }

    @Test("Transport sets itself as delegate on the central manager")
    func transportSetsDelegateOnManager() {
        #expect(mockCentralManager.delegate === sut)
    }

    // MARK: - Start scanning

    @Test("connect begins scan for the service UUID")
    func startScanningScanForServiceUUID() {
        // When
        sut.startScanning()

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == true)
        #expect(mockCentralManager.scannedServiceUUIDs == [CBUUID(nsuuid: serviceUUID)])
    }

    @Test("connect does not scan when central manager is not powered on")
    func startScanningWaitsWhenNotPoweredOn() {
        // Given
        mockCentralManager.state = .poweredOff

        // When
        sut.startScanning()

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == false)
    }

    @Test("connect does not scan again if already scanning")
    func startScanningDoesNotDoubleScan() {
        // Given
        sut.startScanning()
        mockCentralManager.didCallScanForPeripherals = false

        // When
        sut.startScanning()

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == false)
    }

    // MARK: - Stop scanning

    @Test("stopScanning stops scan on the central manager")
    func stopScanningSendsStopScan() {
        // Given
        sut.startScanning()

        // When
        sut.stopScanning()

        // Then
        #expect(mockCentralManager.didCallStopScan == true)
    }

    @Test("stopScanning does nothing when not already scanning")
    func stopScanningDoesNothingWhenNotScanning() {
        // When
        sut.stopScanning()

        // Then
        #expect(mockCentralManager.didCallStopScan == false)
    }

    // MARK: - Delegate callbacks

    @Test("handleDidUpdateState notifies delegate when powered on")
    func didUpdateStatePoweredOnNotifiesDelegate() {
        // When
        sut.handleDidUpdateState(for: mockCentralManager)

        // Then
        #expect(mockDelegate.didPowerOnCalled == true)
    }

    @Test("handleDidUpdateState notifies delegate of failure when not powered on")
    func didUpdateStateNotPoweredOnNotifiesFailure() {
        // Given
        mockCentralManager.state = .poweredOff

        // When
        sut.handleDidUpdateState(for: mockCentralManager)

        // Then
        #expect(mockDelegate.didFailError == .notPoweredOn(.poweredOff))
    }

    @Test("handleDidUpdateState notifies delegate of failure when permissions denied")
    func didUpdateStatePermissionsDeniedNotifiesFailure() {
        // Given
        mockCentralManager.authorization = .denied

        // When
        sut.handleDidUpdateState(for: mockCentralManager)

        // Then
        #expect(mockDelegate.didFailError == .permissionsNotGranted(.denied))
    }

    @Test("handleDidUpdateState notifies delegate of failure when permissions restricted")
    func didUpdateStatePermissionsRestrictedNotifiesFailure() {
        // Given
        mockCentralManager.authorization = .restricted

        // When
        sut.handleDidUpdateState(for: mockCentralManager)

        // Then
        #expect(mockDelegate.didFailError == .permissionsNotGranted(.restricted))
    }

    // MARK: - Connect

    @Test("connect calls centralManager.connect with the discovered peripheral")
    func connectCallsCentralManagerConnect() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.connect()

        // Then
        #expect(mockCentralManager.didCallConnect == true)
    }

    @Test("connect reports error when no peripheral is set")
    func connectReportsErrorWhenNoPeripheral() {
        // When
        sut.connect()

        // Then
        #expect(mockDelegate.didFailError == .connectError)
    }

    @Test("handleDidConnect notifies delegate")
    func handleDidConnectNotifiesDelegate() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()

        // When
        sut.handleDidConnect(mockPeripheral)

        // Then
        #expect(mockDelegate.didConnectCalled == true)
    }

    // MARK: - Discover Services

    @Test("discoverServices calls discoverServices on peripheral with the service UUID")
    func discoverServicesCallsPeripheral() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.discoverServices()

        // Then
        #expect(mockPeripheral.discoverServicesCalled == true)
        #expect(mockPeripheral.discoveredServiceUUIDs == [CBUUID(nsuuid: serviceUUID)])
    }

    @Test("discoverServices sets peripheral delegate to self")
    func discoverServicesSetsDelegate() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.discoverServices()

        // Then
        #expect(mockPeripheral.delegate === sut)
    }

    @Test("handleDidDiscoverServices notifies delegate on success")
    func handleDidDiscoverServicesNotifiesDelegate() {
        // When
        sut.handleDidDiscoverServices(error: nil)

        // Then
        #expect(mockDelegate.didDiscoverServicesCalled == true)
    }

    @Test("handleDidDiscoverServices reports error when error is present")
    func handleDidDiscoverServicesReportsError() {
        // Given
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "mDL GATT service not found"])

        // When
        sut.handleDidDiscoverServices(error: error)

        // Then
        #expect(mockDelegate.didFailError == .discoverServicesError("mDL GATT service not found."))
    }

    // MARK: - Discover Characteristics

    @Test("discoverCharacteristics calls discoverCharacteristics on peripheral for the matching service")
    func discoverCharacteristicsCallsPeripheral() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        mockPeripheral.services = [service]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.discoverCharacteristics()

        // Then
        #expect(mockPeripheral.discoverCharacteristicsCalled == true)
        let expectedUUIDs = CharacteristicType.allCases.map { $0.cbUUID }
        #expect(mockPeripheral.discoveredCharacteristicUUIDs == expectedUUIDs)
    }

    @Test("discoverCharacteristics reports error when service is not found")
    func discoverCharacteristicsReportsErrorWhenServiceNotFound() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        mockPeripheral.services = []
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.discoverCharacteristics()

        // Then
        #expect(mockDelegate.didFailError == .discoverServicesError("mDL GATT service not found"))
    }

    @Test("discoverCharacteristics reports error when peripheral is nil")
    func discoverCharacteristicsReportsErrorWhenNoPeripheral() {
        // When
        sut.discoverCharacteristics()

        // Then
        #expect(mockDelegate.didFailError == .discoverServicesError("mDL GATT service not found"))
    }

    @Test("handleDidDiscoverCharacteristics notifies delegate with service on success")
    func handleDidDiscoverCharacteristicsNotifiesDelegate() {
        // Given
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)

        // When
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // Then
        #expect(mockDelegate.didDiscoverCharacteristicsService === service)
    }

    @Test("handleDidDiscoverCharacteristics reports error when error is present")
    func handleDidDiscoverCharacteristicsReportsError() {
        // Given
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Discovery failed"])

        // When
        sut.handleDidDiscoverCharacteristics(for: service, error: error)

        // Then
        #expect(mockDelegate.didFailError == .discoverCharacteristicsError("Discovery failed"))
    }

    // MARK: - End Session

    @Test("endSession calls cancelPeripheralConnection on the central manager")
    func endSessionCancelsConnection() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.endSession(andNotify: false)

        // Then
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    @Test("endSession reports error when no peripheral is set")
    func endSessionReportsErrorWhenNoPeripheral() {
        // When
        sut.endSession(andNotify: false)

        // Then
        #expect(mockDelegate.didFailError == .connectError)
    }

    @Test("endSession with andNotify true writes GATT End to State characteristic when connection is established")
    func endSessionAndNotifyWritesGattEnd() {
        // Given — connection established
        let mockPeripheral = establishConnection(mtu: 512)

        // When
        sut.endSession(andNotify: true)

        // Then — writes 0x02 to the State characteristic
        #expect(mockPeripheral.writeValueCalled == true)
        #expect(mockPeripheral.writtenData == ConnectionState.end.data)
        #expect(mockPeripheral.writtenType == .withoutResponse)
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    @Test("endSession with andNotify false does not write GATT End even when connection is established")
    func endSessionWithoutNotifyDoesNotWriteGattEnd() {
        // Given — connection established
        let mockPeripheral = establishConnection(mtu: 512)

        // When
        sut.endSession(andNotify: false)

        // Then — no write to State, but still cancels connection
        #expect(mockPeripheral.writeValueCalled == false)
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    @Test("endSession with andNotify true does not write GATT End when connection was not established")
    func endSessionAndNotifyDoesNotWriteWhenNotEstablished() {
        // Given — peripheral set but connection not established (writeStart never called)
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.endSession(andNotify: true)

        // Then — no write since connectionEstablished is false
        #expect(mockPeripheral.writeValueCalled == false)
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    // MARK: - Start Transport

    @Test("startTransport subscribes to State and Server2Client characteristics")
    func startTransportSubscribesToCharacteristics() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        sut.startTransport()

        // Then
        #expect(mockPeripheral.setNotifyValueCalled == true)
        #expect(mockPeripheral.setNotifyCharacteristics.count == 2)
    }

    @Test("startTransport does not write Start immediately")
    func startTransportDoesNotWriteImmediately() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        sut.startTransport()

        // Then
        #expect(mockPeripheral.writeValueCalled == false)
    }

    @Test("startTransport reports gattServiceMissing error when gattService is nil")
    func startTransportReportsErrorWhenGattServiceNil() {
        // Given - no service discovered, so gattService is nil

        // When
        sut.startTransport()

        // Then
        #expect(mockDelegate.didFailError == .gattServiceMissing)
    }

    @Test("startTransport reports error when peripheral is nil")
    func startTransportReportsErrorWhenPeripheralNil() {
        // Given - discover characteristics to set gattService, but don't discover a peripheral
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        sut.startTransport()

        // Then
        #expect(mockDelegate.didFailError == .discoverServicesError("GATT Service peripheral not stored."))
    }

    @Test("startTransport reports error when State characteristic is missing")
    func startTransportReportsErrorWhenStateCharacteristicMissing() {
        // Given - service with no State characteristic
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        sut.startTransport()

        // Then
        #expect(mockDelegate.didFailError == .discoverCharacteristicsError("State characteristic is missing from GATT Service."))
    }

    @Test("startTransport reports error when Server2Client characteristic is missing")
    func startTransportReportsErrorWhenServerToClientCharacteristicMissing() {
        // Given - service with State but no Server2Client characteristic
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        service.characteristics = [stateChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        sut.startTransport()

        // Then
        #expect(mockDelegate.didFailError == .discoverCharacteristicsError("Server2Client characteristic is missing from GATT Service."))
    }

    // MARK: - Subscription Success

    @Test("handleDidUpdateNotificationState sets stateSubscribed on State characteristic success")
    func subscriptionSuccessSetsStateFlag() {
        // Given
        let stateChar = CBMutableCharacteristic(characteristic: .state)

        // When
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)

        // Then
        #expect(sut.stateSubscribed == true)
        #expect(sut.serverToClientSubscribed == false)
    }

    @Test("handleDidUpdateNotificationState sets serverToClientSubscribed on Server2Client success")
    func subscriptionSuccessSetsServerToClientFlag() {
        // Given
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)

        // When
        sut.handleDidUpdateNotificationState(for: serverToClientChar, error: nil)

        // Then
        #expect(sut.serverToClientSubscribed == true)
        #expect(sut.stateSubscribed == false)
    }

    @Test("handleDidUpdateNotificationState writes Start after both subscriptions succeed")
    func subscriptionSuccessWritesStartAfterBoth() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)
        sut.startTransport()

        // When
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)
        sut.handleDidUpdateNotificationState(for: serverToClientChar, error: nil)

        // Then
        #expect(mockPeripheral.writeValueCalled == true)
        #expect(mockPeripheral.writtenData == ConnectionState.start.data)
        #expect(mockPeripheral.writtenType == .withoutResponse)
    }

    @Test("handleDidUpdateNotificationState does not write Start after only one subscription")
    func subscriptionSuccessDoesNotWriteAfterOnlyOne() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)

        // Then
        #expect(mockPeripheral.writeValueCalled == false)
    }

    // MARK: - Subscription Failure

    @Test("handleDidUpdateNotificationState reports error on failure")
    func subscriptionFailureReportsError() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let error = NSError(domain: "test", code: 1)

        // When
        sut.handleDidUpdateNotificationState(for: stateChar, error: error)

        // Then
        #expect(mockDelegate.didFailError == .transportError("Failed to subscribe to characteristics"))
    }

    @Test("handleDidUpdateNotificationState terminates BLE connection on failure")
    func subscriptionFailureTerminatesConnection() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let error = NSError(domain: "test", code: 1)

        // When
        sut.handleDidUpdateNotificationState(for: stateChar, error: error)

        // Then
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    // MARK: - Write Start Failure

    @Test("writeStart fails when canSendWriteWithoutResponse is false")
    func writeStartFailsWhenCannotSend() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        mockPeripheral.canSendWriteWithoutResponse = false
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)
        sut.startTransport()

        // When - trigger writeStart via both subscriptions succeeding
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)
        sut.handleDidUpdateNotificationState(for: serverToClientChar, error: nil)

        // Then
        #expect(mockPeripheral.writeValueCalled == false)
        #expect(mockDelegate.didFailError == .transportError("Failed to write 'Start' state"))
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    @Test("writeStart fails when State characteristic is missing from gattService")
    func writeStartFailsWhenStateCharacteristicMissing() {
        // Given - service without State characteristic so writeStart's first guard fails
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When - trigger writeStart by setting both subscription flags
        // Use a characteristic with state UUID to set stateSubscribed, even though it's not in the service
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        sut.handleDidUpdateNotificationState(for: serverToClientChar, error: nil)
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)

        // Then
        #expect(mockPeripheral.writeValueCalled == false)
        #expect(mockDelegate.didFailError == .transportError("Failed to write 'Start' state"))
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    // MARK: - Handle Did Update Value (Server2Client)

    @Test("AC1: intermediate packet (0x01) buffers data without emitting")
    func intermediatePacketBuffersData() {
        // Given
        let characteristic = CBMutableCharacteristic(characteristic: .serverToClient)
        characteristic.value = Data([0x01, 0xAA, 0xBB])

        // When
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // Then
        #expect(sut.characteristicData[.serverToClient] == Data([0xAA, 0xBB]))
        #expect(mockDelegate.receivedMessageData == nil)
    }

    @Test("AC1: multiple intermediate packets accumulate in buffer")
    func multipleIntermediatePacketsAccumulate() {
        // Given
        let characteristic = CBMutableCharacteristic(characteristic: .serverToClient)

        // When - first chunk
        characteristic.value = Data([0x01, 0xAA, 0xBB])
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // When - second chunk
        characteristic.value = Data([0x01, 0xCC, 0xDD])
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // Then
        #expect(sut.characteristicData[.serverToClient] == Data([0xAA, 0xBB, 0xCC, 0xDD]))
        #expect(mockDelegate.receivedMessageData == nil)
    }

    @Test("AC2: final packet (0x00) emits assembled message and clears buffer")
    func finalPacketEmitsAndClears() {
        // Given
        let characteristic = CBMutableCharacteristic(characteristic: .serverToClient)

        // When - intermediate
        characteristic.value = Data([0x01, 0xAA, 0xBB])
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // When - final
        characteristic.value = Data([0x00, 0xCC])
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // Then
        #expect(mockDelegate.receivedMessageData == Data([0xAA, 0xBB, 0xCC]))
        #expect(sut.characteristicData[.serverToClient] == nil)
    }

    @Test("AC2: single-packet message (0x00 only) emits immediately")
    func singlePacketEmitsImmediately() {
        // Given
        let characteristic = CBMutableCharacteristic(characteristic: .serverToClient)
        characteristic.value = Data([0x00, 0x01, 0x02, 0x03])

        // When
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // Then
        #expect(mockDelegate.receivedMessageData == Data([0x01, 0x02, 0x03]))
        #expect(sut.characteristicData[.serverToClient] == nil)
    }

    @Test("AC3: invalid header byte clears buffer and reports error")
    func invalidHeaderClearsBufferAndErrors() {
        // Given - pre-fill buffer with prior data
        let characteristic = CBMutableCharacteristic(characteristic: .serverToClient)
        characteristic.value = Data([0x01, 0xAA])
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // When - invalid header
        characteristic.value = Data([0xFF, 0xBB])
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // Then
        #expect(sut.characteristicData[.serverToClient] == nil)
        #expect(mockDelegate.didFailError == .serverToClientError("Invalid data received, first byte was not 0x01 or 0x00."))
        #expect(mockDelegate.receivedMessageData == nil)
    }

    @Test("AC3: empty byte array clears buffer and reports error")
    func emptyDataClearsBufferAndErrors() {
        // Given - pre-fill buffer
        let characteristic = CBMutableCharacteristic(characteristic: .serverToClient)
        characteristic.value = Data([0x01, 0xAA])
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // When - empty data
        characteristic.value = Data()
        sut.handleDidUpdateValue(for: characteristic, error: nil)

        // Then
        #expect(sut.characteristicData[.serverToClient] == nil)
        #expect(mockDelegate.didFailError == .serverToClientError("Invalid data received, empty byte array."))
    }

    @Test("handleDidUpdateValue reports transport error when error is present")
    func updateValueWithErrorReportsTransportError() {
        // Given
        let characteristic = CBMutableCharacteristic(characteristic: .serverToClient)
        characteristic.value = Data([0x00, 0x01])
        let error = NSError(domain: "test", code: 1)

        // When
        sut.handleDidUpdateValue(for: characteristic, error: error)

        // Then
        #expect(mockDelegate.didFailError == .transportError("Failed to read characteristic value"))
        #expect(mockDelegate.receivedMessageData == nil)
    }

    // MARK: - Send Data

    /// Helper: establishes a BLE connection by discovering characteristics,
    /// subscribing to both notifications, and triggering writeStart.
    /// Returns the mock peripheral configured with the given MTU.
    @discardableResult
    private func establishConnection(mtu: Int) -> MockBluetoothPeripheral {
        let mockPeripheral = MockBluetoothPeripheral()
        mockPeripheral.maximumWriteValueLengthValue = mtu
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        let clientToServerChar = CBMutableCharacteristic(characteristic: .clientToServer)
        service.characteristics = [stateChar, serverToClientChar, clientToServerChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)
        sut.startTransport()

        // Subscribe to both characteristics to trigger writeStart
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)
        sut.handleDidUpdateNotificationState(for: serverToClientChar, error: nil)

        // Reset tracking after connection setup
        mockPeripheral.allWrittenData = []
        mockPeripheral.writeValueCalled = false
        mockPeripheral.writtenData = nil
        mockPeripheral.writtenCharacteristic = nil
        mockPeripheral.writtenType = nil
        mockDelegate.didFailError = nil
        mockDelegate.didFinishSendingCalled = false

        return mockPeripheral
    }

    // MARK: - Final or only chunk transmission (0x00 header)

    @Test("Single chunk message prepends 0x00 header and writes to Client2Server")
    func sendSingleChunkPrependsEndOfDataHeader() {
        // Given - MTU of 512 means chunk size is 511, payload fits in one chunk
        let mockPeripheral = establishConnection(mtu: 512)
        let payload = Data([0xAA, 0xBB, 0xCC])

        // When
        sut.send(payload)

        // Then
        #expect(mockPeripheral.writeValueCalled == true)
        #expect(mockPeripheral.allWrittenData.count == 1)
        let expected = Data([MessageDataFirstByte.endOfData.rawValue]) + payload
        #expect(mockPeripheral.allWrittenData[0] == expected)
    }

    @Test("Final chunk uses .writeWithoutResponse type")
    func sendFinalChunkUsesWriteWithoutResponse() {
        // Given
        let mockPeripheral = establishConnection(mtu: 512)

        // When
        sut.send(Data([0x01, 0x02]))

        // Then
        #expect(mockPeripheral.writtenType == .withoutResponse)
    }

    @Test("Final chunk writes to the Client2Server characteristic")
    func sendFinalChunkWritesToClientToServerCharacteristic() {
        // Given
        let mockPeripheral = establishConnection(mtu: 512)

        // When
        sut.send(Data([0x01]))

        // Then
        #expect(mockPeripheral.writtenCharacteristic?.uuid == CharacteristicType.clientToServer.cbUUID)
    }

    @Test("Delegate is notified when sending completes")
    func sendNotifiesDelegateDidFinishSending() {
        // Given
        establishConnection(mtu: 512)

        // When
        sut.send(Data([0xAA, 0xBB]))

        // Then
        #expect(mockDelegate.didFinishSendingCalled == true)
    }

    @Test("Data exactly equal to chunk size sends a single 0x00 packet")
    func sendDataExactlyChunkSizeSendsSinglePacket() {
        // Given - MTU of 5 means chunk size is 4 (5 - 1 for header)
        let mockPeripheral = establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04])

        // When
        sut.send(data)

        // Then - single final chunk
        #expect(mockPeripheral.allWrittenData.count == 1)
        #expect(mockPeripheral.allWrittenData[0] == Data([0x00, 0x01, 0x02, 0x03, 0x04]))
    }

    // MARK: - Intermediate chunk transmission (0x01 header)

    @Test("Intermediate chunks are prefixed with 0x01")
    func sendIntermediateChunksArePrefixedWithMoreData() {
        // Given - MTU of 5 means chunk size is 4
        let mockPeripheral = establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])

        // When
        sut.send(data)

        // Then - 2 intermediate (4 bytes each) + 1 final (1 byte)
        #expect(mockPeripheral.allWrittenData.count == 3)
        #expect(mockPeripheral.allWrittenData[0].first == MessageDataFirstByte.moreData.rawValue)
        #expect(mockPeripheral.allWrittenData[1].first == MessageDataFirstByte.moreData.rawValue)
    }

    @Test("Final chunk after intermediates is prefixed with 0x00")
    func sendFinalChunkAfterIntermediatesIsPrefixedWithEndOfData() {
        // Given - MTU of 5 means chunk size is 4
        let mockPeripheral = establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])

        // When
        sut.send(data)

        // Then
        let lastChunk = mockPeripheral.allWrittenData.last
        #expect(lastChunk?.first == MessageDataFirstByte.endOfData.rawValue)
    }

    @Test("Chunked data reassembles to original payload when headers are stripped")
    func sendChunkedDataReassemblesToOriginalPayload() {
        // Given - MTU of 5 means chunk size is 4
        let mockPeripheral = establishConnection(mtu: 5)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])

        // When
        sut.send(data)

        // Then - strip headers and reassemble
        let reassembled = mockPeripheral.allWrittenData.reduce(Data()) { result, chunk in
            result + chunk.dropFirst()
        }
        #expect(reassembled == data)
    }

    @Test("All writes use .writeWithoutResponse type")
    func sendAllChunksUseWriteWithoutResponse() {
        // Given - MTU of 5 means chunk size is 4, need multiple chunks
        let mockPeripheral = establishConnection(mtu: 5)
        let data = Data(repeating: 0xAA, count: 12)

        // When
        sut.send(data)

        // Then - all 3 chunks written with .withoutResponse
        #expect(mockPeripheral.allWrittenData.count == 3)
        #expect(mockPeripheral.writtenType == .withoutResponse)
    }

    @Test("All writes target the Client2Server characteristic")
    func sendAllChunksWriteToClientToServer() {
        // Given
        let mockPeripheral = establishConnection(mtu: 5)
        let data = Data(repeating: 0xBB, count: 9)

        // When
        sut.send(data)

        // Then
        #expect(mockPeripheral.allWrittenData.count == 3)
        #expect(mockPeripheral.writtenCharacteristic?.uuid == CharacteristicType.clientToServer.cbUUID)
    }

    // MARK: - Write returns false (queue full)

    @Test("send stores pendingData when queue is full during intermediate chunk")
    func sendStoresPendingDataWhenQueueFullOnIntermediateChunk() {
        // Given - MTU of 5 means chunk size is 4
        let mockPeripheral = establishConnection(mtu: 5)
        let data = Data(repeating: 0xAA, count: 12) // 3 chunks needed

        // Allow first write, then block
        mockPeripheral.canSendWriteWithoutResponse = true

        // We need to make canSendWriteWithoutResponse return false after first write
        // The mock checks this before each write in the while loop
        // Set it to false before calling send so it will bail on the first iteration
        mockPeripheral.canSendWriteWithoutResponse = false

        // When
        sut.send(data)

        // Then - no writes occurred, data stored as pending
        #expect(mockPeripheral.allWrittenData.isEmpty)
        #expect(sut.pendingData == data)
        #expect(mockDelegate.didFinishSendingCalled == false)
    }

    @Test("send stores remaining pendingData when queue fills during final chunk")
    func sendStoresPendingDataWhenQueueFullOnFinalChunk() {
        // Given - single chunk that fits, but queue is full
        let mockPeripheral = establishConnection(mtu: 512)
        let data = Data([0xAA, 0xBB, 0xCC])

        // Queue is full - cannot send
        mockPeripheral.canSendWriteWithoutResponse = false

        // When
        sut.send(data)

        // Then - data stored as pending, delegate NOT called
        #expect(mockPeripheral.allWrittenData.isEmpty)
        #expect(sut.pendingData == data)
        #expect(mockDelegate.didFinishSendingCalled == false)
    }

    @Test("handlePeripheralIsReady resumes transmission with pendingData")
    func handlePeripheralIsReadyResumesSending() {
        // Given - establish connection, set pending data
        let mockPeripheral = establishConnection(mtu: 512)
        let data = Data([0x01, 0x02, 0x03])
        sut.pendingData = data
        mockPeripheral.canSendWriteWithoutResponse = true

        // When
        sut.handlePeripheralIsReady()

        // Then - data was sent and pending cleared
        #expect(sut.pendingData == nil)
        #expect(mockPeripheral.allWrittenData.count == 1)
        let expected = Data([MessageDataFirstByte.endOfData.rawValue]) + data
        #expect(mockPeripheral.allWrittenData[0] == expected)
        #expect(mockDelegate.didFinishSendingCalled == true)
    }

    @Test("handlePeripheralIsReady does nothing when no pendingData")
    func handlePeripheralIsReadyDoesNothingWithNoPendingData() {
        // Given
        let mockPeripheral = establishConnection(mtu: 512)
        #expect(sut.pendingData == nil)

        // When
        sut.handlePeripheralIsReady()

        // Then
        #expect(mockPeripheral.allWrittenData.isEmpty)
        #expect(mockDelegate.didFinishSendingCalled == false)
    }

    // MARK: - Write error (stop transmission)

    @Test("send reports error when connection not established")
    func sendReportsErrorWhenConnectionNotEstablished() {
        // Given - no connection established (no subscription + writeStart)
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.send(Data([0x01]))

        // Then
        #expect(mockPeripheral.writeValueCalled == false)
        #expect(
            mockDelegate.didFailError == .clientToServerError(
                "Cannot send data: connection not established or characteristic unavailable."
            )
        )
    }

    @Test("send reports error when characteristic is unavailable")
    func sendReportsErrorWhenCharacteristicUnavailable() {
        // Given - establish connection but with a service that has no clientToServer characteristic
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        // Intentionally omit clientToServer characteristic
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // Subscribe to trigger writeStart and set connectionEstablished = true
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)
        sut.handleDidUpdateNotificationState(for: serverToClientChar, error: nil)
        mockDelegate.didFailError = nil
        mockPeripheral.allWrittenData = []

        // When
        sut.send(Data([0x01]))

        // Then
        #expect(
            mockDelegate.didFailError == .clientToServerError(
                "Cannot send data: connection not established or characteristic unavailable."
            )
        )
    }

    @Test("send does not call didFinishSending when error occurs")
    func sendDoesNotCallFinishSendingOnError() {
        // Given - no connection
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // When
        sut.send(Data([0x01]))

        // Then
        #expect(mockDelegate.didFinishSendingCalled == false)
    }

    // MARK: - Valid chunk size calculation

    @Test("Chunk size is maximumWriteValueLength minus 1 byte for ISO header")
    func sendChunkSizeIsMaxWriteValueLengthMinusOne() {
        // Given - MTU of 10 means chunk size is 9 (10 - 1 for ISO header)
        let mockPeripheral = establishConnection(mtu: 10)
        // 18 bytes of data -> 2 chunks of 9
        let data = Data(repeating: 0xAA, count: 18)

        // When
        sut.send(data)

        // Then - 1 intermediate (9 bytes payload) + 1 final chunk (9 bytes payload)
        #expect(mockPeripheral.allWrittenData.count == 2)
        // Each chunk (including header) should be 10 bytes total
        let firstChunkPayload = mockPeripheral.allWrittenData[0].dropFirst()
        let secondChunkPayload = mockPeripheral.allWrittenData[1].dropFirst()
        #expect(firstChunkPayload.count == 9)
        #expect(secondChunkPayload.count == 9)
    }

    @Test("Chunk size respects the peripheral's negotiated MTU")
    func sendChunkSizeRespectsPeripheralMTU() {
        // Given - small MTU of 4 means chunk size is 3
        let mockPeripheral = establishConnection(mtu: 4)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])

        // When
        sut.send(data)

        // Then - 6 bytes / 3 bytes per chunk = 1 intermediate + 1 final
        #expect(mockPeripheral.allWrittenData.count == 2)
        // First chunk: header (0x01) + 3 bytes payload = 4 bytes total
        #expect(mockPeripheral.allWrittenData[0].count == 4)
        // Last chunk: header (0x00) + 3 bytes payload = 4 bytes total
        #expect(mockPeripheral.allWrittenData[1].count == 4)
    }

    @Test("Large payload is correctly split across many chunks")
    func sendLargePayloadSplitsCorrectly() {
        // Given - MTU of 6 means chunk size is 5
        let mockPeripheral = establishConnection(mtu: 6)
        let data = Data(repeating: 0xCC, count: 23)
        // 23 / 5 = 4 full chunks + 3 remaining = 5 chunks total (4 intermediate + 1 final)

        // When
        sut.send(data)

        // Then
        #expect(mockPeripheral.allWrittenData.count == 5)
        // First 4 are intermediate (0x01 header)
        for i in 0..<4 {
            #expect(mockPeripheral.allWrittenData[i].first == MessageDataFirstByte.moreData.rawValue)
            #expect(mockPeripheral.allWrittenData[i].count == 6)
        }
        // Last is final (0x00 header) with 3 bytes
        #expect(mockPeripheral.allWrittenData[4].first == MessageDataFirstByte.endOfData.rawValue)
        #expect(mockPeripheral.allWrittenData[4].count == 4) // header + 3 remaining bytes
    }
}
// swiftlint:enable file_length
