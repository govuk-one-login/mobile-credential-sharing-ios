import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    
    var session: HolderSession?
    var startPresentationCalled = false
    var cancelPresentationCalled = false
    
    func startTransaction() {
        startPresentationCalled = true
    }
    
    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        // Protocol func not used in this Mock
    }
    
    func userDidTapApprove() {
        // Protocol func not used in this Mock
    }
    
    func userDidTapDeny() {
        // Protocol func not used in this Mock
    }
    
    func userDidTapCancel() {
        cancelPresentationCalled = true
    }

    func qrCodeGenerationDidFail() {
        // Protocol func not used in this Mock
    }
}
