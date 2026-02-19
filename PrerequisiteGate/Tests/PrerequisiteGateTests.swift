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
        let mockPeripheralSession = MockPeripheralSession()
        sut.peripheralSession = mockPeripheralSession
        let capabilities: [Capability] = [.bluetooth()]
        
        for state in [CBManagerState.poweredOn, .poweredOff, .resetting, .unknown, .unauthorized, .unsupported] {
            mockPeripheralSession.mockPeripheralManagerState = state
            
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
        let mockPeripheralSession = MockPeripheralSession(mockPeripheralManagerState: .poweredOn)
        let capabilities: [Capability] = [.bluetooth()]
        
        for auth in [CBManagerAuthorization.allowedAlways, .notDetermined, .denied, .restricted] {
            sut = PrerequisiteGate(cbManagerAuthorization: auth)
            sut.peripheralSession = mockPeripheralSession
            
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
    
    @Test("Ensures cbPeripheralManagerShowPowerAlertKey is set to true when PrerequisiteGate is initialized")
    mutating func showPowerAlertKeyIsTrue() throws {
        // Given
        sut = PrerequisiteGate()
        
        // Then
        #expect(sut.cbPeripheralManagerShowPowerAlertKey == true)
    }
    
    @Test("checkCapabilities initialises a PeripheralSession if one does not exist")
    func initsPeripheralSession() {
        // Given
        #expect(sut.peripheralSession == nil)

        // When
        _ = sut.checkCapabilities()
        
        // Then
        #expect(sut.peripheralSession != nil)
    }
    
    @Test("requestPermission(for .bluetooth(.bluetoothAuthNotDetermined)) initiates a PeripheralSession")
    func requestPermissionInitiatesCorrectly() {
        // Given
        #expect(sut.peripheralSession == nil)
        
        // When
        sut.requestPermission(for: .bluetooth(.bluetoothAuthNotDetermined))
        
        // Then
        #expect(sut.peripheralSession != nil)
    }
    
    @Test("requestPermission(for .bluetooth(.bluetoothAuthNotDetermined)) assigns self as PeripheralSession delegate")
    func requestPermissionAssignsDelegate() {
        // Given
        #expect(sut.peripheralSession?.delegate == nil)
        
        // When
        sut.requestPermission(for: .bluetooth(.bluetoothAuthNotDetermined))
        
        // Then
        #expect(sut.peripheralSession?.delegate === sut.self)
    }
}

class MockPrerequisiteGateDelegate: PrerequisiteGateDelegate {
    func bluetoothTransportDidUpdateState() {
        
    }
}

class MockPeripheralSession: PeripheralSessionProtocol {
    weak var delegate: (any BluetoothTransport.PeripheralSessionDelegate)?
    
    var mockPeripheralManagerState: CBManagerState
    init(mockPeripheralManagerState: CBManagerState = .poweredOn) {
        self.mockPeripheralManagerState = mockPeripheralManagerState
    }
    
    func peripheralManagerState() -> CBManagerState {
        return mockPeripheralManagerState
    }
}
