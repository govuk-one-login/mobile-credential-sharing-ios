import Orchestration
import PrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    var delegate: (any Orchestration.HolderOrchestratorDelegate)?
    
    func requestPermission(for capability: Capability) {
        
    }
    
    var session: Orchestration.HolderSession?
    var startPresentationCalled = false
    
    func startPresentation() {
        startPresentationCalled = true
    }
    
    func cancelPresentation() {
        
    }
}
