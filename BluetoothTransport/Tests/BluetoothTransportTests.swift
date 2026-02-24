@testable import BluetoothTransport
import Foundation
import Testing

@Suite("BluetoothTransport tests")
struct BluetoothTransportTests {
    @Test("startAdvertising initializes a new PeripheralSession")
    func startAdvertisingInitializesPeripheralSession() throws {
        // Given
        let sut = BluetoothTransport()
        #expect(sut.peripheralSession == nil)
        let mockSession = MockBluetoothSession()
        mockSession.serviceUUID = UUID()
        
        // When
        try sut.startAdvertising(in: mockSession)
        
        // Then
        #expect(sut.peripheralSession != nil)
        #expect(type(of: try #require(sut.peripheralSession)) == PeripheralSession.self)
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
    
    @Test("peripheralSessionDidUpdateState calls startAdvertising on PeripheralSession")
    func didUpdateStateCallsStartAdvertising() async throws {
        // Given
        let mockPeripheralSession = MockPeripheralSession()
        let sut = BluetoothTransport(peripheralSession: mockPeripheralSession)
        #expect(mockPeripheralSession.didCallStartAdvertising == false)
        
        // When
        sut.peripheralSessionDidUpdateState(withError: nil)
        
        // Then
        #expect(mockPeripheralSession.didCallStartAdvertising == true)
    }
    
    @Test("peripheralSessionDidStartAdvertising calls delegate method")
    func didStartAdvertisingCallsDelegateMethod() async throws {
        // Given
        let mockDelegate = MockBluetoothTransportDelegate()
        let sut = BluetoothTransport()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didCallStartAdvertising == false)
        
        // When
        sut.peripheralSessionDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.didCallStartAdvertising == true)
    }
}
