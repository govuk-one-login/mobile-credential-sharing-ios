import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    
    var session: HolderSession?
    var startPresentationCalled = false
    var cancelPresentationCalled = false
    var resolveCalled = false
    var resolvedPrerequisite: MissingPrerequisite?
    var userDidTapApproveCalled = false
    var userDidTapDenyCalled = false
    var qrCodeGenerationDidFailCalled = false
    
    func startTransaction() {
        startPresentationCalled = true
    }
    
    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
        resolvedPrerequisite = missingPrerequisite
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

    func qrCodeGenerationDidFail() {
        qrCodeGenerationDidFailCalled = true
    }
}
