@testable import BluetoothTransport
import Foundation
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
    func startAdvertisingThrowsError() throws {
        // Given
        let sut = BluetoothTransport()
        let mockSession = MockBluetoothSession()
        
        // When
        mockSession.serviceUUID = nil
        
        // Then
        #expect(throws: PeripheralError.addServiceError("serviceUUID not set").self) {
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
        sut.bluetoothTransportDidFail(with: .unknown)
        
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
}
