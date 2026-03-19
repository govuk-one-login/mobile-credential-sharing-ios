import CoreBluetooth
import Foundation
import SharingBluetoothTransport
@testable import SharingPrerequisiteGate
import Testing

@Suite("Prerequisite Gate Tests")
struct PrerequisiteGateTests {
    var sut = PrerequisiteGate()
    
    @Test("checkCapabilities returns correct MissingCapability for each CBManagerState")
    func checkCapabilitesReturnCorrectState() throws {
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        sut.blePeripheralTransport = mockBlePeripheralTransport
        let capabilities: [Capability] = [.bluetooth]
        
        for state in [CBManagerState.poweredOn, .poweredOff, .resetting, .unknown, .unauthorized, .unsupported] {
            mockBlePeripheralTransport.mockPeripheralManagerState = state
            
            switch state {
            case .poweredOn:
                #expect(sut.checkCapabilities(for: capabilities) == [])
            case .unknown:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStateUnknown)])
            case .resetting:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStateResetting)])
            case .unsupported:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStateUnsupported)])
            case .unauthorized:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthDenied)])
            case .poweredOff:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStatePoweredOff)])
            @unknown default:
                fatalError("Should never be reached as all cases are covered")
            }
        }
    }
    
    @Test("checkCapabilities returns correct MissingCapability for each CBManagerAuthorization")
    mutating func checkCapabilitesReturnCorrectAuth() throws {
        let mockPeripheralSession = MockBlePeripheralTransport(mockPeripheralManagerState: .poweredOn)
        let capabilities: [Capability] = [.bluetooth]
        
        for auth in [CBManagerAuthorization.allowedAlways, .notDetermined, .denied, .restricted] {
            sut = PrerequisiteGate(cbManagerAuthorization: auth, requestBluetoothPowerOn: BluetoothPowerOnRequest<MockCBPeripheralManager>()
                .callAsFunction())
            sut.blePeripheralTransport = mockPeripheralSession
            
            switch auth {
            case .notDetermined:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthNotDetermined)])
            case .restricted:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthRestricted)])
            case .denied:
                #expect(sut.checkCapabilities(for: capabilities) == [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthDenied)])
            case .allowedAlways:
                #expect(sut.checkCapabilities(for: capabilities) == [])
            @unknown default:
                fatalError("Should never be reached as all cases are covered")
            }
        }
    }
    
    @Test("Ensures CBPeripheralManager is initialized when requestPermission(for: MissingCapability(.bluetooth, .bluetoothStatePoweredOff))")
    mutating func showPowerAlertKeyIsTrue() throws {
        // Given
        MockCBPeripheralManager.initCalled = false
        #expect(MockCBPeripheralManager.initCalled == false)
        sut = PrerequisiteGate(
            cbManagerAuthorization: .allowedAlways,
            requestBluetoothPowerOn: BluetoothPowerOnRequest<MockCBPeripheralManager>().callAsFunction()
        )
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        sut.blePeripheralTransport = mockBlePeripheralTransport
        
        // When
        sut.requestPermission(for: MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStatePoweredOff))
        
        // Then
        #expect(MockCBPeripheralManager.initCalled == true)
        #expect(MockCBPeripheralManager.options as? [String: Bool] == [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }
    
    @Test("checkCapabilities initialises a BlePeripheralTransport if one does not exist")
    func initsPeripheralSession() {
        // Given
        #expect(sut.blePeripheralTransport == nil)

        // When
        _ = sut.checkCapabilities()
        
        // Then
        #expect(sut.blePeripheralTransport != nil)
    }
    
    @Test("requestPermission(for MissingCapability(.bluetooth, .bluetoothAuthNotDetermined)) initiates a BlePeripheralTransport")
    func requestPermissionInitiatesCorrectly() {
        // Given
        #expect(sut.blePeripheralTransport == nil)
        
        // When
        sut.requestPermission(for: MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthNotDetermined))
        
        // Then
        #expect(sut.blePeripheralTransport != nil)
    }
    
    @Test("requestPermission(for MissingCapability(.bluetooth, .bluetoothAuthNotDetermined)) assigns self as BlePeripheralTransport delegate")
    func requestPermissionAssignsDelegate() {
        // Given
        #expect(sut.blePeripheralTransport?.delegate == nil)
        
        // When
        sut.requestPermission(for: MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthNotDetermined))
        
        // Then
        #expect(sut.blePeripheralTransport?.delegate === sut.self)
    }
    
    @Test("bluetoothTransportDidPowerOn calls delegate func")
    func bluetoothTransportDidPowerOnCallsDelegate() async throws {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didReportChangeCalled == false)
        
        // When
        sut.bluetoothTransportDidPowerOn()
        
        // Then
        #expect(mockDelegate.didReportChangeCalled == true)
    }
    
    @Test("bluetoothTransportDidFail calls delegate func")
    func bluetoothTransportDidFailCallsDelegate() async throws {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didReportChangeCalled == false)
        
        // When
        sut.bluetoothTransportDidFail(with: .unknown)
        
        // Then
        #expect(mockDelegate.didReportChangeCalled == true)
    }
    
    @Test("bluetoothTransportDidStartAdvertising does not forward to delegate")
    func didStartAdvertisingDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didReportChangeCalled == false)
        
        // When
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.didReportChangeCalled == false)
    }
    
    @Test("bluetoothTransportConnectionDidConnect does not forward to delegate")
    func didConnectCentralDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didReportChangeCalled == false)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(mockDelegate.didReportChangeCalled == false)
    }
    
    @Test("bluetoothTransportDidReceiveMessageData does not forward to delegate")
    func didReceiveMessageDataDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didReportChangeCalled == false)
        
        // When
        sut.bluetoothTransportDidReceiveMessageData(Data())
        
        // Then
        #expect(mockDelegate.didReportChangeCalled == false)    }
    
    @Test("bluetoothTransportDidReceiveMessageEndRequest does not forward to delegate")
    func didReceiveMessageEndRequestDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didReportChangeCalled == false)
        
        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()
        
        // Then
        #expect(mockDelegate.didReportChangeCalled == false)
    }
}
