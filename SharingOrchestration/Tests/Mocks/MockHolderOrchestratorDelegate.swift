import SharingOrchestration

class MockHolderOrchestratorDelegate: HolderOrchestratorDelegate {
    var stateToRender: HolderSessionState?
    
    func orchestrator(didUpdateState state: HolderSessionState?) {
        stateToRender = state
    }
}
