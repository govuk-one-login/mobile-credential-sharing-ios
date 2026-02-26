import BluetoothTransport
import CoreBluetooth
import Foundation
@testable import PrerequisiteGate
import Testing

@Suite("Prerequisite Gate Tests")
struct PrerequisiteGateTests {
    var sut = PrerequisiteGate()
    
    @Test("checkCapabilities returns correct CapabilityDisallowedReason for each CBManagerState")
    func checkCapabilitesReturnCorrectState() throws {
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        sut.blePeripheralTransport = mockBlePeripheralTransport
        let capabilities: [Capability] = [.bluetooth()]
        
        for state in [CBManagerState.poweredOn, .poweredOff, .resetting, .unknown, .unauthorized, .unsupported] {
            mockBlePeripheralTransport.mockPeripheralManagerState = state
            
            switch state {
            case .poweredOn:
                #expect(sut.checkCapabilities(for: capabilities) == [])
            case .unknown:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothStateUnknown)])
            case .resetting:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothStateResetting)])
            case .unsupported:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothStateUnsupported)])
            case .unauthorized:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothAuthDenied)])
            case .poweredOff:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothStatePoweredOff)])
            @unknown default:
                fatalError("Should never be reached as all cases are covered")
            }
        }
    }
    
    @Test("checkCapabilities returns correct CapabilityDisallowedReason for each CBManagerAuthorization")
    mutating func checkCapabilitesReturnCorrectAuth() throws {
        let mockPeripheralSession = MockBlePeripheralTransport(mockPeripheralManagerState: .poweredOn)
        let capabilities: [Capability] = [.bluetooth()]
        
        for auth in [CBManagerAuthorization.allowedAlways, .notDetermined, .denied, .restricted] {
            sut = PrerequisiteGate(cbManagerAuthorization: auth, requestBluetoothPowerOn: BluetoothPowerOnRequest<MockCBPeripheralManager>()
                .callAsFunction())
            sut.blePeripheralTransport = mockPeripheralSession
            
            switch auth {
            case .notDetermined:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothAuthNotDetermined)])
            case .restricted:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothAuthRestricted)])
            case .denied:
                #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothAuthDenied)])
            case .allowedAlways:
                #expect(sut.checkCapabilities(for: capabilities) == [])
            @unknown default:
                fatalError("Should never be reached as all cases are covered")
            }
        }
    }
    
    @Test("Ensures CBPeripheralManager is initialized when requestPermission(for: .bluetooth(.bluetoothStatePoweredOff)")
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
        sut.requestPermission(for: .bluetooth(.bluetoothStatePoweredOff))
        
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
    
    @Test("requestPermission(for .bluetooth(.bluetoothAuthNotDetermined)) initiates a BlePeripheralTransport")
    func requestPermissionInitiatesCorrectly() {
        // Given
        #expect(sut.blePeripheralTransport == nil)
        
        // When
        sut.requestPermission(for: .bluetooth(.bluetoothAuthNotDetermined))
        
        // Then
        #expect(sut.blePeripheralTransport != nil)
    }
    
    @Test("requestPermission(for .bluetooth(.bluetoothAuthNotDetermined)) assigns self as BlePeripheralTransport delegate")
    func requestPermissionAssignsDelegate() {
        // Given
        #expect(sut.blePeripheralTransport?.delegate == nil)
        
        // When
        sut.requestPermission(for: .bluetooth(.bluetoothAuthNotDetermined))
        
        // Then
        #expect(sut.blePeripheralTransport?.delegate === sut.self)
    }
    
    @Test("peripheralTransportDidUpdateState calls delegate func")
    func didUpdateStateCallsDelegate() async throws {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didUpdateStateCalled == false)
        
        // When
        sut.peripheralTransportDidUpdateState(withError: nil)
        
        // Then
        #expect(mockDelegate.didUpdateStateCalled == true)
    }
    
    @Test("peripheralTransportDidStartAdvertising does not forward to delegate")
    func didStartAdvertisingDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didUpdateStateCalled == false)
        
        // When
        sut.peripheralTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.didUpdateStateCalled == false)
    }
    
    @Test("peripheralTransportDidConnectCentral does not forward to delegate")
    func didConnectCentralDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didUpdateStateCalled == false)
        
        // When
        sut.peripheralTransportDidConnectCentral()
        
        // Then
        #expect(mockDelegate.didUpdateStateCalled == false)
    }
    
    @Test("peripheralTransportDidReceiveMessageData does not forward to delegate")
    func didReceiveMessageDataDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didUpdateStateCalled == false)
        
        // When
        sut.peripheralTransportDidReceiveMessageData(Data())
        
        // Then
        #expect(mockDelegate.didUpdateStateCalled == false)    }
    
    @Test("peripheralTransportDidReceiveMessageEndRequest does not forward to delegate")
    func didReceiveMessageEndRequestDoesNotCallDelegate() {
        // Given
        let mockDelegate = MockPrerequisiteGateDelegate()
        sut.delegate = mockDelegate
        #expect(mockDelegate.didUpdateStateCalled == false)
        
        // When
        sut.peripheralTransportDidReceiveMessageEndRequest()
        
        // Then
        #expect(mockDelegate.didUpdateStateCalled == false)
    }
}
