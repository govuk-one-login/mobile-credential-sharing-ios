import SharingOrchestration

class MockVerifierOrchestrator: VerifierOrchestratorProtocol {
    weak var delegate: (any VerifierOrchestratorDelegate)?
    var startVerificationCalled = false
    var cancelVerificationCalled = false

    func startVerification() {
        startVerificationCalled = true
    }

    func cancelVerification() {
        cancelVerificationCalled = true
    }
}
