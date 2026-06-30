import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?

    var session: ISOHolderSession?
    var startCalled = false
    var cancelPresentationCalled = false
    var resolveCalled = false
    var userDidApproveCalled = false
    var userDidDenyCalled = false

    func start() {
        startCalled = true
    }

    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
    }

    func userDidApprove() {
        userDidApproveCalled = true
    }

    func userDidDeny() {
        userDidDenyCalled = true
    }

    func cancel() {
        cancelPresentationCalled = true
    }
}
