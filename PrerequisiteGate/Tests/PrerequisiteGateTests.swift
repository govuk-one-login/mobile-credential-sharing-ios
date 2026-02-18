import BluetoothTransport
import Foundation
@testable import PrerequisiteGate
import Testing

@Suite("Prerequisite Gate Tests")
struct PrerequisiteGateTests {
    var sut = PrerequisiteGate()
    
    @Test("check capabilities returns [Capabilities]")
    func checkCapabilitesReturnsCorrectly() {
        let capabilities: [Capability] = [.bluetooth()]
        
        // The default permission for bluetooth is set to .allowedAlways for a simulator
        // However, the checkCapabilities function checks for powered on / off as well
        // Since the simulator does not support bluetooth
        // The returned result will be .bluetoothStateUnsupported
        #expect(sut.checkCapabilities(for: capabilities) == [.bluetooth(.bluetoothStateUnsupported)])
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
