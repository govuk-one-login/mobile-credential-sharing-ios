import CoreBluetooth
@testable import SharingBluetoothTransport
import Testing

@Suite("BleCentralTransportTests")
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
}
