import SharingOrchestration

class MockHolderOrchestratorDelegate: HolderOrchestratorDelegate {
    var stateToRender: HolderSessionState?
    var cancelConfirmationRequested = false
    var didFinishCalled = false
    
    func orchestrator(didUpdateState state: HolderSessionState?) {
        stateToRender = state
    }

    func orchestratorDidRequestCancelConfirmation() {
        cancelConfirmationRequested = true
    }

    func orchestratorDidFinish() {
        didFinishCalled = true
    }

    func orchestratorFailedRecoverably() {
        // not called
    }
}
