import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    
    var session: HolderSession?
    var startPresentationCalled = false
    var cancelPresentationCalled = false
    var resolveCalled = false
    var userDidTapApproveCalled = false
    var userDidTapDenyCalled = false
    
    func startPresentation() {
        startPresentationCalled = true
    }
    
    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
    }
    
    func userDidTapApprove() {
        userDidTapApproveCalled = true
    }
    
    func userDidTapDeny() {
        userDidTapDenyCalled = true
    }
    
    func userDidTapCancel() {
        cancelPresentationCalled = true
    }
}
