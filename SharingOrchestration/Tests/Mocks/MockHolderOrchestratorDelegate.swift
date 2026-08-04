import SharingOrchestration

class MockHolderOrchestratorDelegate: HolderOrchestratorDelegate {
    var stateToRender: HolderSessionState?
    var cancelConfirmationRequested = false
    
    func orchestrator(didUpdateState state: HolderSessionState?) {
        stateToRender = state
    }

    func orchestratorDidRequestCancelConfirmation() {
        cancelConfirmationRequested = true
    }
}
