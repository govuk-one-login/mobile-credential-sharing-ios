import SharingOrchestration

class MockVerifierOrchestratorDelegate: VerifierOrchestratorDelegate {
    var stateToRender: VerifierSessionState?
    var statesReceived: [VerifierSessionState?] = []
    var cancelConfirmationRequested = false

    func orchestrator(didUpdateState state: VerifierSessionState?) {
        stateToRender = state
        statesReceived.append(state)
    }

    func orchestratorDidRequestCancelConfirmation() {
        cancelConfirmationRequested = true
    }
}
