import CoreBluetooth
import Foundation
@testable import SharingBluetoothTransport
import Testing

// swiftlint:disable file_length
@Suite("BluetoothTransport tests")
// swiftlint:disable:next type_body_length
struct BluetoothTransportTests {
    @Test("startAdvertising initializes a new BlePeripheralTransport")
    func startAdvertisingInitializesPeripheralSession() throws {
        // Given
        let sut = BluetoothTransport()
        #expect(sut.blePeripheralTransport == nil)
        let mockSession = MockBluetoothSession()
        mockSession.serviceUUID = UUID()
        
        // When
        try sut.startAdvertising(in: mockSession)
        
        // Then
        #expect(sut.blePeripheralTransport != nil)
        #expect(try #require(sut.blePeripheralTransport) is BlePeripheralTransport)
    }
    
    @Test("startAdvertising throws correct error if no serviceUUID is set")
    func startAdvertisingNoServiceUUIDThrowsError() throws {
        // Given
        let sut = BluetoothTransport()
        let mockSession = MockBluetoothSession()
        
        // When
        mockSession.serviceUUID = nil
        
        // Then
        #expect(throws: PeripheralError.addServiceError("serviceUUID not set")) {
            try sut.startAdvertising(in: mockSession)
        }
    }
    
    @Test("startAdvertising throws correct error if no blePeripheralTransport is set")
    func startAdvertisingNoBlePeripheralTransportThrowsError() throws {
        // Given
        let sut = BluetoothTransport()
        let mockSession = MockBluetoothSession()
        mockSession.serviceUUID = UUID()
        try sut.startAdvertising(in: mockSession)
        
        // When
        /// We can only mock forcing the delegate to be nil, but the error throw covers both transport & delegate nil checks
        sut.blePeripheralTransport?.delegate = nil
        
        // Then
        #expect(throws: PeripheralError.addServiceError("blePeripheralTransport should not be nil")) {
            try sut.startAdvertising(in: mockSession)
        }
    }
    
    @Test("bluetoothTransportDidPowerOn calls startAdvertising on BlePeripheralTransport")
    func didUpdateStateCallsStartAdvertising() async throws {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        let sut = BluetoothTransport(blePeripheralTransport: mockBlePeripheralTransport)
        #expect(mockBlePeripheralTransport.didCallStartAdvertising == false)
        
        // When
        sut.bluetoothTransportDidPowerOn()
        
        // Then
        #expect(mockBlePeripheralTransport.didCallStartAdvertising == true)
    }
    
    @Test("bluetoothTransportDidStartAdvertising calls delegate method")
    func didStartAdvertisingCallsDelegateMethod() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallStartAdvertising == false)
        
        // When
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.didCallStartAdvertising == true)
    }
    
    @Test("bluetoothTransportConnectionDidConnect calls delegate method")
    func didConnectCentralCallsDelegateMethod() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallConnectionDidConnect == false)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(mockDelegate.didCallConnectionDidConnect == true)
    }
    
    @Test("bluetoothTransportDidReceiveMessageData calls delegate method")
    func didReceiveMessageDataCallsDelegateMethod() throws {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallDidReceiveMessageData == false)
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockDelegate.didCallDidReceiveMessageData == true)
        #expect(mockDelegate.receivedMessageData == data)
    }
    
    @Test("bluetoothTransportDidFail calls delegate method")
    func didFailCallsDelegateMethod() throws {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallDidFail == false)
        
        // When
        sut.bluetoothTransportDidFail(with: .peripheral(.unknown))
        
        // Then
        #expect(mockDelegate.didCallDidFail == true)
    }
    
    @Test("bluetoothTransportDidReceiveMessageEndRequest calls delegate method")
    func didReceiveMessageEndRequest() throws {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didReceiveMessageEndRequest == false)
        
        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()
        
        // Then
        #expect(mockDelegate.didReceiveMessageEndRequest == true)
    }
    
    @Test("bluetoothTransportDidFinishSending calls delegate method")
    func didFinishSendingCallsDelegateMethod() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallDidFinishSending == false)
        
        // When
        sut.bluetoothTransportDidFinishSending()
        
        // Then
        #expect(mockDelegate.didCallDidFinishSending == true)
    }

    @Test("sendSessionData forwards data to blePeripheralTransport")
    func sendSessionDataForwardsToPeripheralTransport() {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        let sut = BluetoothTransport(
            blePeripheralTransport: mockBlePeripheralTransport
        )
        let data = Data([0xA1, 0x66, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x14])
        #expect(mockBlePeripheralTransport.didCallSendData == false)
        // When
        sut.sendSessionData(data)

        // Then
        #expect(mockBlePeripheralTransport.didCallSendData == true)
        #expect(mockBlePeripheralTransport.lastSentData == data)
    }

    @Test("sendGattEnd calls endSession with andNotify true on blePeripheralTransport")
    func sendGattEndCallsEndSessionOnPeripheralTransport() {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        let sut = BluetoothTransport(
            blePeripheralTransport: mockBlePeripheralTransport
        )
        #expect(mockBlePeripheralTransport.didCallEndSession == false)

        // When
        sut.sendGattEnd()

        // Then
        #expect(mockBlePeripheralTransport.didCallEndSession == true)
        #expect(mockBlePeripheralTransport.endSessionAndNotify == true)
    }

    @Test("sendSessionData forwards data to bleCentralTransport when available")
    func sendSessionDataForwardsToCentralTransport() {
        // Given
        let mockBleCentralTransport = MockBleCentralTransport()
        let sut = BluetoothTransport(
            blePeripheralTransport: nil,
            bleCentralTransport: mockBleCentralTransport
        )
        let data = Data([0xA1, 0x66, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x14])
        #expect(mockBleCentralTransport.sendDataCalled == false)

        // When
        sut.sendSessionData(data)

        // Then
        #expect(mockBleCentralTransport.sendDataCalled == true)
        #expect(mockBleCentralTransport.sentData == data)
    }

    @Test("sendGattEnd calls endSession with andNotify true on bleCentralTransport when available")
    func sendGattEndCallsEndSessionOnCentralTransport() {
        // Given
        let mockBleCentralTransport = MockBleCentralTransport()
        let sut = BluetoothTransport(
            blePeripheralTransport: nil,
            bleCentralTransport: mockBleCentralTransport
        )
        #expect(mockBleCentralTransport.endSessionCalled == false)

        // When
        sut.sendGattEnd()

        // Then
        #expect(mockBleCentralTransport.endSessionCalled == true)
        #expect(mockBleCentralTransport.endSessionAndNotify == true)
    }

    // MARK: - Central Tests

    @Test("connect creates bleCentralTransport")
    func startScanningCreatesTransport() throws {
        // Given
        let sut = BluetoothTransport()
        let session = MockBluetoothSession()
        session.serviceUUID = UUID()

        // When
        try sut.connect(in: session)

        // Then
        #expect(sut.bleCentralTransport != nil)
    }

    @Test("connect throws when session has no service UUID")
    func startScanningThrows() {
        // Given
        let sut = BluetoothTransport()
        let session = MockBluetoothSession()

        // Then
        #expect(throws: CentralError.serviceUUIDNotSet) {
            try sut.connect(in: session)
        }
    }

    @Test("startTransport calls startTransport on bleCentralTransport")
    func startTransportCallsCentralTransport() {
        // Given
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        #expect(mockCentral.startTransportCalled == false)

        // When
        sut.startTransport()

        // Then
        #expect(mockCentral.startTransportCalled == true)
    }

    @Test("bluetoothTransportDidDiscover forwards to delegate")
    func bluetoothTransportDidDiscoverForwardsToDelegate() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallDidDiscover == false)

        // When
        sut.bluetoothTransportDidDiscover()

        // Then
        #expect(mockDelegate.didCallDidDiscover == true)
    }

    @Test("bleCentralTransportDidPowerOn forwards to delegate")
    func centralDidPowerOnForwards() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate

        // When
        sut.bleCentralTransportDidPowerOn()

        // Then
        #expect(mockDelegate.didCallDidPowerOn == true)
    }

    @Test("bleCentralTransportDidDiscoverPeripheral stops scanning, connects, and forwards as didDiscover to delegate")
    func centralDidDiscoverForwards() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate

        // When
        sut.bleCentralTransportDidDiscoverPeripheral()

        // Then
        #expect(mockCentral.stopScanningCalled == true)
        #expect(mockCentral.connectCalled == true)
        #expect(mockDelegate.didCallDidDiscover == true)
    }

    @Test("bleCentralTransportDidFail forwards as .central error to delegate")
    func centralDidFailForwards() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate

        // When
        sut.bleCentralTransportDidFail(with: .notPoweredOn(.poweredOff))

        // Then
        #expect(mockDelegate.didCallDidFail == true)
    }

    @Test("bleCentralTransportDidRecieveMessageData forwards to delegate")
    func centralDidRecieveMessageDataForwards() throws {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate
        let data = try #require(Data(base64Encoded: "AQID"))

        // When
        sut.bleCentralTransportDidReceiveMessageData(data)

        // Then
        #expect(mockDelegate.didCallDidReceiveMessageData == true)
        #expect(mockDelegate.receivedMessageData == data)
    }
    
    @Test("sendData calls startTransport on bleCentralTransport")
    func sendDataCallsCentralTransport() {
        // Given
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        #expect(mockCentral.startTransportCalled == false)

        // When
        sut.send(Data())

        // Then
        #expect(mockCentral.sendDataCalled == true)
    }

    // MARK: - Service Discovery Flow

    @Test("bleCentralTransportDidConnect triggers discoverServices")
    func didConnectTriggersDiscoverServices() {
        // Given
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)

        // When
        sut.bleCentralTransportDidConnect()

        // Then
        #expect(mockCentral.discoverServicesCalled == true)
    }

    @Test("bleCentralTransportDidDiscoverServices triggers discoverCharacteristics")
    func didDiscoverServicesTriggersDiscoverCharacteristics() {
        // Given
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)

        // When
        sut.bleCentralTransportDidDiscoverServices()

        // Then
        #expect(mockCentral.discoverCharacteristicsCalled == true)
    }

    @Test("bleCentralTransportDidDiscoverCharacteristics with mismatched UUIDs reports error")
    func didDiscoverCharacteristicsWithMismatchReportsError() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate
        let service = CBMutableService(type: CBUUID(string: "00000001-A123-48CE-896B-4C76973373E6"), primary: true)
        let wrongCharacteristic = CBMutableCharacteristic(
            type: CBUUID(string: "FFFFFFFF-A123-48CE-896B-4C76973373E6"),
            properties: .read,
            value: nil,
            permissions: .readable
        )
        service.characteristics = [wrongCharacteristic]

        // When
        sut.bleCentralTransportDidDiscoverCharacteristics(for: service)

        // Then
        #expect(mockDelegate.didCallDidFail == true)
    }

    @Test("bleCentralTransportDidDiscoverCharacteristics with correct UUIDs but wrong properties reports error")
    func didDiscoverCharacteristicsWithWrongPropertiesReportsError() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate
        let service = CBMutableService(type: CBUUID(string: "00000001-A123-48CE-896B-4C76973373E6"), primary: true)
        let stateChar = CBMutableCharacteristic(
            type: CharacteristicType.state.cbUUID,
            properties: [.read],  // Wrong: should be .notify, .writeWithoutResponse
            value: nil,
            permissions: .readable
        )
        let clientToServerChar = CBMutableCharacteristic(
            type: CharacteristicType.clientToServer.cbUUID,
            properties: [.writeWithoutResponse],
            value: nil,
            permissions: .readable
        )
        let serverToClientChar = CBMutableCharacteristic(
            type: CharacteristicType.serverToClient.cbUUID,
            properties: [.notify],
            value: nil,
            permissions: .readable
        )
        service.characteristics = [stateChar, clientToServerChar, serverToClientChar]

        // When
        sut.bleCentralTransportDidDiscoverCharacteristics(for: service)

        // Then
        #expect(mockDelegate.didCallDidFail == true)
    }

    @Test("bleCentralTransportDidDiscoverCharacteristics with nil characteristics does not crash")
    func didDiscoverCharacteristicsWithNilCharacteristics() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate
        let service = CBMutableService(type: CBUUID(string: "00000001-A123-48CE-896B-4C76973373E6"), primary: true)
        service.characteristics = nil

        // When
        sut.bleCentralTransportDidDiscoverCharacteristics(for: service)

        // Then - should not crash, early return
        #expect(mockDelegate.didCallDidFail == false)
    }

    @Test("bleCentralTransportDidDiscoverCharacteristics with correct characteristics does not report error")
    func didDiscoverCharacteristicsWithCorrectUUIDsSucceeds() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate
        let service = CBMutableService(type: CBUUID(string: "00000001-A123-48CE-896B-4C76973373E6"), primary: true)
        let stateChar = CBMutableCharacteristic(
            type: CharacteristicType.state.cbUUID,
            properties: [.notify, .writeWithoutResponse],
            value: nil,
            permissions: .readable
        )
        let clientToServerChar = CBMutableCharacteristic(
            type: CharacteristicType.clientToServer.cbUUID,
            properties: [.writeWithoutResponse],
            value: nil,
            permissions: .readable
        )
        let serverToClientChar = CBMutableCharacteristic(
            type: CharacteristicType.serverToClient.cbUUID,
            properties: [.notify],
            value: nil,
            permissions: .readable
        )
        service.characteristics = [stateChar, clientToServerChar, serverToClientChar]

        // When
        sut.bleCentralTransportDidDiscoverCharacteristics(for: service)

        // Then
        #expect(mockDelegate.didCallDidFail == false)
    }

    @Test("bluetoothTransportDidStartSession calls delegate method")
    func didStartSessionCallsDelegateMethod() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallDidStartSession == false)

        // When
        sut.bluetoothTransportDidStartSession()

        // Then
        #expect(mockDelegate.didCallDidStartSession == true)
    }

    @Test("bleCentralTransportDidStartSession forwards to delegate")
    func centralDidStartSessionForwards() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallDidStartSession == false)

        // When
        sut.bleCentralTransportDidStartSession()

        // Then
        #expect(mockDelegate.didCallDidStartSession == true)
    }

    @Test("bleCentralTransportDidFinishSending forwards to delegate")
    func centralDidFinishSendingForwards() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallDidFinishSending == false)

        // When
        sut.bleCentralTransportDidFinishSending()

        // Then
        #expect(mockDelegate.didCallDidFinishSending == true)
    }
}
