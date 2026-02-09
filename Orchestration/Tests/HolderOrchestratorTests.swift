@testable import Orchestration
import Testing

@Suite("HolderOrchestrator Tests")
struct HolderOrchestratorTests {
    let sut = HolderOrchestrator()
    
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
    
//    @Test("performPreflightChecks sets current state to .preflight(missingPermissions)")
//    func preflightChecksSetsCorrectState()  {
//        // When
//        sut.startPresentation()
//        #expect(sut.session?.currentState == .preflight(missingPermissions: [.bluetooth]))
//    }
}
