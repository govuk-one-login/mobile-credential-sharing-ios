import Foundation
@testable import SharingBluetoothTransport
import Testing

@Suite("BluetoothTransport tests")
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

    // MARK: - Central Tests

    @Test("startScanning forwards to bleCentralTransport")
    func startScanningForwards() throws {
        // Given
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        let session = MockBluetoothSession()
        session.serviceUUID = UUID()

        // When
        try sut.startScanning(in: session)

        // Then
        #expect(mockCentral.startScanningCalled == true)
    }

    @Test("startScanning throws when bleCentralTransport throws")
    func startScanningThrows() {
        // Given
        let mockCentral = MockBleCentralTransport()
        mockCentral.startScanningShouldThrow = CentralError.serviceUUIDNotSet
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        let session = MockBluetoothSession()

        // Then
        #expect(throws: CentralError.serviceUUIDNotSet) {
            try sut.startScanning(in: session)
        }
    }

    @Test("stopScanning forwards to bleCentralTransport")
    func stopScanningForwards() {
        // Given
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)

        // When
        sut.stopScanning()

        // Then
        #expect(mockCentral.handleDidStopScanningCalled == true)
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

    @Test("bleCentralTransportDidDiscoverPeripheral forwards as didDiscover to delegate")
    func centralDidDiscoverForwards() {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let mockCentral = MockBleCentralTransport()
        let sut = BluetoothTransport(bleCentralTransport: mockCentral)
        sut.delegate = mockDelegate

        // When
        sut.bleCentralTransportDidDiscoverPeripheral()

        // Then
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
}
