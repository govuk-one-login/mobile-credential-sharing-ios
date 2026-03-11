import SharingOrchestration

class MockHolderOrchestratorDelegate: HolderOrchestratorDelegate {
    var stateToRender: HolderSessionState?
    
    func render(for state: HolderSessionState?) {
        stateToRender = state
    }
}
