import BluetoothTransport
import CoreBluetooth
import Foundation
@testable import PrerequisiteGate
import Testing

@Suite("Prerequisite Gate Tests")
struct PrerequisiteGateTests {
    var sut = PrerequisiteGate()
    
    @Test("check capabilities returns [Capabilities]")
    func checkCapabilitesReturnsCorrectly() {
        sut.peripheralSession = MockPeripheralSession(mockPeripheralManagerState: .poweredOff)
        let capabilities: [Capability] = [.bluetooth()]
        
        // The default permission for bluetooth is set to .allowedAlways for a simulator
        // However, the checkCapabilities function checks for powered on / off as well
        // Since the simulator does not have bluetooth
        // The returned result will be .bluetoothStateUnknown
        #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothStatePoweredOff)])
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
    func bluetoothTransportDidUpdateState(withError error: BluetoothTransport.PeripheralError?) {
        
    }
}

class MockPeripheralSession: PeripheralSessionProtocol {
    weak var delegate: (any BluetoothTransport.PeripheralSessionDelegate)?
    
    var mockPeripheralManagerState: CBManagerState = .poweredOn
    init(mockPeripheralManagerState: CBManagerState) {
        self.mockPeripheralManagerState = mockPeripheralManagerState
    }
    
    func peripheralManagerState() -> CBManagerState {
        return mockPeripheralManagerState
    }
}
