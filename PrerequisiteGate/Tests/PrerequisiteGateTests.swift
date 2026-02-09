import Foundation
@testable import PrerequisiteGate
import Testing

@Suite("Prerequisite Gate Tests")
struct PrerequisiteGateTests {
    let sut = PrerequisiteGate()
    
    @Test("check capabilities returns [Capabilities]")
    func checkCapabilitesReturnsCorrectly() {
        // Given
        let capabilities: [Capability] = [.bluetooth]
        #expect(PrerequisiteGate.checkCapabilities(for: capabilities).isEmpty)
    }
}
