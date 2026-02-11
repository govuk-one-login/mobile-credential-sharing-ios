import BluetoothTransport
@testable import Orchestration
import PrerequisiteGate
import Testing

@Suite("HolderOrchestrator Tests")
struct HolderOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var sut: HolderOrchestrator
    
    init() {
        sut = HolderOrchestrator(prerequisiteGate: mockPrerequisiteGate)
    }
    
    @Test("startPresentation creates a new HolderSession object")
    func startPresentationCreatesHolderSession() {
        // Given
        #expect(sut.session == nil)
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(sut.session != nil)
    }
    
    @Test("cancelPresentation sets the session to nil")
    func cancelPresentationSetsSessionToNil() {
        // Given
        sut.startPresentation()
        #expect(sut.session != nil)
        
        // When
        sut.cancelPresentation()
        
        // Then
        #expect(sut.session == nil)
    }
    
    @Test("bluetoothTransportDidUpdateState with no error triggers performPreflightChecks()")
    func bluetoothTransportDidUpdateStatePreflightChecks() {
        // Given
        #expect(sut.prerequisiteGate == nil)
        
        // When
        sut.bluetoothTransportDidUpdateState(withError: nil)
        
        // Then
        /// performPreflightChecks inits prerequisiteGate
        #expect(sut.prerequisiteGate != nil)
    }
    
    @Test("bluetoothTransportDidUpdateState with an error does not trigger performPreflightChecks()")
    func bluetoothTransportDidUpdateStateNoPreflightChecks() {
        // Given
        #expect(sut.prerequisiteGate == nil)
        
        // When
        sut.bluetoothTransportDidUpdateState(withError: PeripheralError.notPoweredOn(.poweredOff))
        
        // Then
        #expect(sut.prerequisiteGate == nil)
    }
    
    @Test("startPresentation successfully transitions to .readyToPresent when capabilities are allowed")
    func startPresentationProceedsToReadyToPresent() {
        // Given
        mockPrerequisiteGate.notAllowedCapabilities = []
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(sut.session?.currentState == .readyToPresent)
    }
    
    @Test("startPresentation successfully transitions to .preflight when capabilities are not allowed")
    func startPresentationProceedsToPreflight() {
        // Given
        mockPrerequisiteGate.notAllowedCapabilities = [.bluetooth]
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(sut.session?.currentState == .preflight(missingPermissions: mockPrerequisiteGate.notAllowedCapabilities))
    }
}

class MockPrerequisiteGate: PrerequisiteGateProtocol {
    var peripheralSession: PeripheralSession?
    
    weak var delegate: PrerequisiteGateDelegate?
    
    var notAllowedCapabilities: [Capability] = []
    func requestPermission(for capability: Capability) {
        
    }
    
    func checkCapabilities(for capabilites: [Capability]) -> [Capability] {
        return notAllowedCapabilities
    }
}
