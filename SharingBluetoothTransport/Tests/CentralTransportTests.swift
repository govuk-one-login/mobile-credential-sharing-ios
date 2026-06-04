import Foundation
@testable import SharingBluetoothTransport
import Testing

@Suite("CentralTransport Tests")
struct CentralTransportTests {

    @Test("init sets itself as delegate on bleCentralTransport")
    func setsDelegateOnInit() {
        // Given
        let mockTransport = MockBleCentralTransport()

        // When
        let sut = CentralTransport(bleCentralTransport: mockTransport)

        // Then
        #expect(mockTransport.delegate === sut)
    }

    @Test("startScanning forwards to bleCentralTransport")
    func startScanningForwards() throws {
        // Given
        let mockTransport = MockBleCentralTransport()
        let sut = CentralTransport(bleCentralTransport: mockTransport)
        let session = MockCentralSession()
        session.serviceUUID = UUID()

        // When
        try sut.startScanning(in: session)

        // Then
        #expect(mockTransport.startScanningCalled == true)
    }

    @Test("startScanning throws when bleCentralTransport throws")
    func startScanningThrows() {
        // Given
        let mockTransport = MockBleCentralTransport()
        mockTransport.startScanningShouldThrow = CentralError.serviceUUIDNotSet
        let sut = CentralTransport(bleCentralTransport: mockTransport)
        let session = MockCentralSession()

        // Then
        #expect(throws: CentralError.serviceUUIDNotSet) {
            try sut.startScanning(in: session)
        }
    }

    @Test("stopScanning forwards to bleCentralTransport")
    func stopScanningForwards() {
        // Given
        let mockTransport = MockBleCentralTransport()
        let sut = CentralTransport(bleCentralTransport: mockTransport)

        // When
        sut.stopScanning()

        // Then
        #expect(mockTransport.handleDidStopScanningCalled == true)
    }

    @Test("bleCentralTransportDidPowerOn forwards to delegate")
    func didPowerOnForwards() {
        // Given
        let mockTransport = MockBleCentralTransport()
        let mockDelegate = MockCentralTransportDelegate()
        let sut = CentralTransport(bleCentralTransport: mockTransport)
        sut.delegate = mockDelegate
        #expect(mockDelegate.didPowerOnCalled == false)

        // When
        sut.bleCentralTransportDidPowerOn()

        // Then
        #expect(mockDelegate.didPowerOnCalled == true)
    }

    @Test("bleCentralTransportDidDiscoverPeripheral forwards to delegate")
    func didDiscoverPeripheralForwards() {
        // Given
        let mockTransport = MockBleCentralTransport()
        let mockDelegate = MockCentralTransportDelegate()
        let sut = CentralTransport(bleCentralTransport: mockTransport)
        sut.delegate = mockDelegate
        #expect(mockDelegate.didDiscoverPeripheralCalled == false)

        // When
        sut.bleCentralTransportDidDiscoverPeripheral()

        // Then
        #expect(mockDelegate.didDiscoverPeripheralCalled == true)
    }

    @Test("bleCentralTransportDidFail forwards error to delegate")
    func didFailForwards() {
        // Given
        let mockTransport = MockBleCentralTransport()
        let mockDelegate = MockCentralTransportDelegate()
        let sut = CentralTransport(bleCentralTransport: mockTransport)
        sut.delegate = mockDelegate
        #expect(mockDelegate.didFailError == nil)

        // When
        sut.bleCentralTransportDidFail(with: .notPoweredOn(.poweredOff))

        // Then
        #expect(mockDelegate.didFailError == .notPoweredOn(.poweredOff))
    }
}
