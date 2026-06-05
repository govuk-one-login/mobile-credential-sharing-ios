import CoreBluetooth
@testable import SharingBluetoothTransport
import Testing

@Suite("BleCentralTransportTests")
struct BleCentralTransportTests {
    let mockCentralManager = MockCBCentralManager()
    let mockDelegate = MockBleCentralTransportDelegate()
    let sut: BleCentralTransport

    init() {
        sut = BleCentralTransport(centralManager: mockCentralManager)
        sut.delegate = mockDelegate
    }

    @Test("Transport sets itself as delegate on the central manager")
    func transportSetsDelegateOnManager() {
        #expect(mockCentralManager.delegate === sut)
    }

    // MARK: - Start scanning

    @Test("serviceCBUUID matches the session's service UUID after scanning starts")
    func serviceCBUUIDMatchesSessionUUID() throws {
        // Given
        let serviceUUID = UUID()
        let session = MockBluetoothSession()
        session.serviceUUID = serviceUUID

        // When
        try sut.startScanning(in: session)

        // Then
        #expect(sut.serviceCBUUID == CBUUID(nsuuid: serviceUUID))
    }

    @Test("startScanning begins scan for the session's service UUID")
    func startScanningScanForServiceUUID() throws {
        // Given
        let serviceUUID = UUID()
        let session = MockBluetoothSession()
        session.serviceUUID = serviceUUID

        // When
        try sut.startScanning(in: session)

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == true)
        #expect(mockCentralManager.scannedServiceUUIDs == [CBUUID(nsuuid: serviceUUID)])
    }

    @Test("startScanning throws when session has no service UUID")
    func startScanningThrowsWhenNoUUID() {
        let session = MockBluetoothSession()

        #expect(throws: CentralError.serviceUUIDNotSet) {
            try sut.startScanning(in: session)
        }
    }

    @Test("startScanning does not scan when central manager is not powered on")
    func startScanningWaitsWhenNotPoweredOn() throws {
        // Given
        mockCentralManager.state = .poweredOff
        let session = MockBluetoothSession()
        session.serviceUUID = UUID()

        // When
        try sut.startScanning(in: session)

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == false)
    }

    @Test("startScanning does not scan again if already scanning")
    func startScanningDoesNotDoubleScan() throws {
        // Given
        let session = MockBluetoothSession()
        session.serviceUUID = UUID()
        try sut.startScanning(in: session)
        mockCentralManager.didCallScanForPeripherals = false

        // When
        try sut.startScanning(in: session)

        // Then
        #expect(mockCentralManager.didCallScanForPeripherals == false)
    }

    // MARK: - Stop scanning

    @Test("stopScanning stops scan on the central manager")
    func stopScanningSendsStopScan() throws {
        // Given
        let session = MockBluetoothSession()
        session.serviceUUID = UUID()
        try sut.startScanning(in: session)

        // When
        sut.stopScanning()

        // Then
        #expect(mockCentralManager.didCallStopScan == true)
    }

    @Test("stopScanning does nothing when not already scanning")
    func stopScanningNoOpWhenNotScanning() {
        // Given
        // sut has not started scanning

        // When
        sut.stopScanning()

        // Then
        #expect(mockCentralManager.didCallStopScan == false)
    }

    // MARK: - Delegate callbacks

    @Test("handleDidUpdateState notifies delegate when powered on")
    func didUpdateStateTriggersScanWhenPoweredOn() throws {
        // Given
        mockCentralManager.state = .poweredOff
        let session = MockBluetoothSession()
        session.serviceUUID = UUID()
        try sut.startScanning(in: session)

        // When
        mockCentralManager.state = .poweredOn
        sut.handleDidUpdateState(for: mockCentralManager)

        // Then
        #expect(mockDelegate.didPowerOnCalled == true)
    }

    @Test("handleDidUpdateState notifies delegate of power on")
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

    @Test("Discovering a peripheral notifies delegate")
    func didDiscoverPeripheralNotifiesDelegate() throws {
        // Given
        let session = MockBluetoothSession()
        session.serviceUUID = UUID()
        try sut.startScanning(in: session)

        // When
        sut.handleDidDiscoverPeripheral()

        // Then
        #expect(mockDelegate.didDiscoverPeripheralCalled == true)
    }
}
