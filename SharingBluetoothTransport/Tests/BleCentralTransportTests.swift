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

    @Test("startScanning begins scan for the service UUID")
    func startScanningScanForServiceUUID() {
        // When
        sut.startScanning()

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == true)
        #expect(mockCentralManager.scannedServiceUUIDs == [CBUUID(nsuuid: serviceUUID)])
    }

    @Test("startScanning does not scan when central manager is not powered on")
    func startScanningWaitsWhenNotPoweredOn() {
        // Given
        mockCentralManager.state = .poweredOff

        // When
        sut.startScanning()

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == false)
    }

    @Test("startScanning does not scan again if already scanning")
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
        sut.endSession()

        // Then
        #expect(mockCentralManager.didCallCancelConnection == true)
    }

    @Test("endSession reports error when no peripheral is set")
    func endSessionReportsErrorWhenNoPeripheral() {
        // When
        sut.endSession()

        // Then
        #expect(mockDelegate.didFailError == .connectError)
    }

    // MARK: - Start Transport

    @Test("startTransport subscribes to State and Server2Client characteristics")
    func startTransportSubscribesToCharacteristics() throws {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        try sut.startTransport()

        // Then
        #expect(mockPeripheral.setNotifyValueCalled == true)
        #expect(mockPeripheral.setNotifyCharacteristics.count == 2)
    }

    @Test("startTransport throws when gattService is nil")
    func startTransportThrowsWhenNoGattService() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)

        // Then
        #expect(throws: CentralError.gattServiceMissing) {
            try sut.startTransport()
        }
    }

    @Test("startTransport does not write Start immediately")
    func startTransportDoesNotWriteImmediately() throws {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let service = CBMutableService(type: CBUUID(nsuuid: serviceUUID), primary: true)
        let stateChar = CBMutableCharacteristic(characteristic: .state)
        let serverToClientChar = CBMutableCharacteristic(characteristic: .serverToClient)
        service.characteristics = [stateChar, serverToClientChar]
        sut.handleDidDiscoverPeripheral(for: mockPeripheral)
        sut.handleDidDiscoverCharacteristics(for: service, error: nil)

        // When
        try sut.startTransport()

        // Then
        #expect(mockPeripheral.writeValueCalled == false)
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

        // When - trigger writeStart via both subscriptions succeeding
        sut.handleDidUpdateNotificationState(for: stateChar, error: nil)
        sut.handleDidUpdateNotificationState(for: serverToClientChar, error: nil)

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
}
// swiftlint:enable file_length
