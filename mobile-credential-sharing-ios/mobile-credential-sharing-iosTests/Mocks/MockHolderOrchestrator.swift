import Orchestration

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    var session: Orchestration.HolderSession?
    var startPresentationCalled = false
    
    func startPresentation() {
        startPresentationCalled = true
    }
    
    func cancelPresentation() {
        
    }
}
