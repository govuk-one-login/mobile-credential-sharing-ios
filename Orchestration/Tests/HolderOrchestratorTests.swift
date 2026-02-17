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
    mutating func bluetoothTransportDidUpdateStatePreflightChecks() {
        // Given
        sut = HolderOrchestrator()
        #expect(sut.prerequisiteGate == nil)
        
        // When
        sut.bluetoothTransportDidUpdateState(withError: nil)
        
        // Then
        /// performPreflightChecks inits prerequisiteGate
        #expect(sut.prerequisiteGate != nil)
    }
    
    @Test("bluetoothTransportDidUpdateState with an error does not trigger performPreflightChecks()")
    mutating func bluetoothTransportDidUpdateStateNoPreflightChecks() {
        // Given
        sut = HolderOrchestrator()
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
        mockPrerequisiteGate.notAllowedCapabilities = [.bluetooth()]
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(sut.session?.currentState == .preflight(missingPermissions: mockPrerequisiteGate.notAllowedCapabilities))
    }
    
    @Test("requestPermissions triggers requestPermission func on PrerequisiteGate")
    func requestPermissionsTriggersPRGateFunc() throws {
        // Given
        _ = try #require(sut.prerequisiteGate)
        #expect(mockPrerequisiteGate.didCallRequestPermission == false)
        
        // When
        sut.requestPermission(for: .bluetooth())
        
        // Then
        #expect(mockPrerequisiteGate.didCallRequestPermission == true)
    }
}
