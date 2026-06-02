import SharingOrchestration

class MockVerifierOrchestratorDelegate: VerifierOrchestratorDelegate {
    var stateToRender: VerifierSessionState?
    var statesReceived: [VerifierSessionState?] = []

    func orchestrator(didUpdateState state: VerifierSessionState?) {
        stateToRender = state
        statesReceived.append(state)
    }
}
