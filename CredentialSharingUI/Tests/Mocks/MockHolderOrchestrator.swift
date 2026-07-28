import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    
    var session: HolderSession?
    var startPresentationCalled = false
    var cancelPresentationCalled = false
    var confirmCancelCalled = false
    var resolveCalled = false
    var userDidTapApproveCalled = false
    var userDidTapDenyCalled = false

    /// When true, userDidTapCancel() will call delegate?.orchestratorDidRequestCancelConfirmation()
    var shouldRequestCancelConfirmation = false
    /// When true, userDidTapCancel() will call delegate?.orchestratorDidDismiss()
    var shouldDismissOnCancel = false
    
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
        if shouldRequestCancelConfirmation {
            delegate?.orchestratorDidRequestCancelConfirmation()
        } else if shouldDismissOnCancel {
            delegate?.orchestratorDidDismiss()
        }
    }

    func userDidConfirmCancel() {
        confirmCancelCalled = true
    }
}
