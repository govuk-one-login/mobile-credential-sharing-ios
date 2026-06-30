import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?

    var session: ISOHolderSession?
    var startCalled = false
    var cancelPresentationCalled = false

    func start() {
        startCalled = true
    }

    func resolve(_ missingPrerequisite: MissingPrerequisite) {
    }

    func userDidApprove() {
    }

    func userDidDeny() {
    }

    func cancel() {
        cancelPresentationCalled = true
    }
}
