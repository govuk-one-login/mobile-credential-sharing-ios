import SharingOrchestration

class MockHolderOrchestratorDelegate: HolderOrchestratorDelegate {
    var stateToRender: HolderSessionState?
    /// Full history of states delivered to the delegate, in order. Used to assert that
    /// an internal state (e.g. `.expired`) is never surfaced to the UI.
    var renderedStates: [HolderSessionState?] = []
    
    func orchestrator(didUpdateState state: HolderSessionState?) {
        stateToRender = state
        renderedStates.append(state)
    }

    func orchestratorFailedRecoverably() {
        // not called
    }
}
