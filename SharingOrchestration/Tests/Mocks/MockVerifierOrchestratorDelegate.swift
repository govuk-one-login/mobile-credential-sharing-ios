import SharingOrchestration

class MockVerifierOrchestratorDelegate: VerifierOrchestratorDelegate {
    var stateToRender: VerifierSessionState?

    func orchestrator(didUpdateState state: VerifierSessionState?) {
        stateToRender = state
    }
}
