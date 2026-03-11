import SharingPrerequisiteGate
import SharingOrchestration

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    
    var session: HolderSession?
    var startPresentationCalled = false
    var cancelPresentationCalled = false
    var requestPermissionCalled = false
    
    func startPresentation() {
        startPresentationCalled = true
    }
    
    func cancelPresentation() {
        cancelPresentationCalled = true
    }
    
    func requestPermission(for capability: Capability) {
        requestPermissionCalled = true
    }
}
