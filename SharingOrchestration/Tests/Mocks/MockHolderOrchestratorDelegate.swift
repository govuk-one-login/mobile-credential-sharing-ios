import SharingOrchestration

class MockHolderOrchestratorDelegate: HolderOrchestratorDelegate {
    var stateToRender: HolderSessionState?
    
    func orchestrator(_ orchestrator: HolderOrchestrator, didUpdateState state: HolderSessionState?) {
        stateToRender = state
    }
}
