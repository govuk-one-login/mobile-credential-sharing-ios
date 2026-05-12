import SharingOrchestration

class MockVerifierOrchestratorDelegate: VerifierOrchestratorDelegate {
    var didUpdateStateCalled: Bool = false
    
    func orchestrator(didUpdateState: String) {
        didUpdateStateCalled = true
    }
}
