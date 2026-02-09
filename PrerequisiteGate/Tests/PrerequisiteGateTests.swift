import Foundation
@testable import PrerequisiteGate
import Testing

@Suite("Prerequisite Gate Tests")
struct PrerequisiteGateTests {
    var sut = PrerequisiteGate()
    
    @Test("check capabilities returns [Capabilities]")
    func checkCapabilitesReturnsCorrectly() {
        let capabilities: [Capability] = [.bluetooth, .camera]
        
        // The default permission is set to .allowedAlways for a simulator, so the checkCapabilities will return only the camera.
        #expect(PrerequisiteGate.checkCapabilities(for: capabilities) == [.camera])
    }
    
    @Test("requestPermission initiates temporary CBPeripheralManager")
    mutating func requestPermissionInitiatesCorrectly() {
        // Given
        #expect(sut.temporaryPeripheralManager == nil)
        
        // When
        sut.requestPermission(for: .bluetooth)
        
        // Then
        #expect(sut.temporaryPeripheralManager != nil)
    }
    
    @Test("requestPermission assigns delegate to TemporaryPeripheralManagerDelegate")
    mutating func requestPermissionAssignsDelegate() {
        // Given
        sut.delegate = MockPrerequisiteGateDelegate()
        #expect(sut.temporaryPeripheralManagerDelegate.delegate == nil)
        
        // When
        sut.requestPermission(for: .bluetooth)
        
        // Then
        #expect(sut.temporaryPeripheralManagerDelegate.delegate === sut.delegate)
    }
}

class MockPrerequisiteGateDelegate: PrerequisiteGateDelegate {
    func didUpdatePermissions() {
        
    }
}
