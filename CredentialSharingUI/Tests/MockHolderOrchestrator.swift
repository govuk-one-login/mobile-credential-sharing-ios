import Orchestration
import PrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any Orchestration.HolderOrchestratorDelegate)?
    
    var session: Orchestration.HolderSession?
    var startPresentationCalled = false
    var requestPermissionCalled = false
    
    func startPresentation() {
        startPresentationCalled = true
    }
    
    func cancelPresentation() {
        
    }
    
    func requestPermission(for capability: Capability) {
        requestPermissionCalled = true
    }
}
