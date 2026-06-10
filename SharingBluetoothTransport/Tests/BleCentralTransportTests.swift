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
        // Given
        let mockPeripheral = MockBluetoothPeripheral()

        // When
        sut.handleDidDiscoverServices(for: mockPeripheral, error: nil)

        // Then
        #expect(mockDelegate.didDiscoverServicesCalled == true)
    }

    @Test("handleDidDiscoverServices reports error when error is present")
    func handleDidDiscoverServicesReportsError() {
        // Given
        let mockPeripheral = MockBluetoothPeripheral()
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "mDL GATT service not found"])

        // When
        sut.handleDidDiscoverServices(for: mockPeripheral, error: error)

        // Then
        #expect(mockDelegate.didFailError == .discoverServicesError("mDL GATT service not found"))
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
        #expect(mockDelegate.didFailError == .discoverCharacteristicsError("Peripheral or service not found"))
    }

    @Test("discoverCharacteristics reports error when peripheral is nil")
    func discoverCharacteristicsReportsErrorWhenNoPeripheral() {
        // When
        sut.discoverCharacteristics()

        // Then
        #expect(mockDelegate.didFailError == .discoverCharacteristicsError("Peripheral or service not found"))
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
        #expect(mockDelegate.didFailError == .discoverServicesError("Discovery failed"))
    }
}
