import SharingOrchestration

class MockVerifierOrchestratorDelegate: VerifierOrchestratorDelegate {
    var didStartCalled = false
    var didCancelCalled = false

    func verifierOrchestrator(didStart: Bool) {
        didStartCalled = didStart
    }

    func verifierOrchestrator(didCancel: Bool) {
        didCancelCalled = didCancel
    }
}
