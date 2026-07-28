import SharingOrchestration

class MockHolderOrchestratorDelegate: HolderOrchestratorDelegate {
    var stateToRender: HolderSessionState?
    var cancelConfirmationRequested = false
    var dismissCalled = false
    
    func orchestrator(didUpdateState state: HolderSessionState?) {
        stateToRender = state
    }

    func orchestratorDidRequestCancelConfirmation() {
        cancelConfirmationRequested = true
    }

    func orchestratorDidDismiss() {
        dismissCalled = true
    }
}
