import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    
    var session: HolderSession?
    var startPresentationCalled = false
    var cancelPresentationCalled = false
    var confirmCancelCalled = false
    
    func startPresentation() {
        startPresentationCalled = true
    }
    
    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        
    }
    
    func userDidTapApprove() {
        
    }
    
    func userDidTapDeny() {
        
    }
    
    func userDidTapCancel() {
        cancelPresentationCalled = true
    }

    func userDidConfirmCancel() {
        confirmCancelCalled = true
    }
}
