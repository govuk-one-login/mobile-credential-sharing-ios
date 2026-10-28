#if DEBUG
import SharingOrchestration
import SharingPrerequisiteGate

public class MockHolderOrchestrator: HolderOrchestratorProtocol {
    public weak var delegate: (any HolderOrchestratorDelegate)?

    public var session: HolderSession?
    public var startPresentationCalled = false
    public var cancelPresentationCalled = false
    public var confirmCancelCalled = false
    public var resolveCalled = false
    public var resolvedPrerequisite: MissingPrerequisite?
    public var userDidTapApproveCalled = false
    public var userDidTapDenyCalled = false

    /// When true, userDidTapCancel() will call delegate?.orchestratorDidRequestCancelConfirmation()
    public var shouldRequestCancelConfirmation = false

    public init() {}

    public func startPresentation() {
        startPresentationCalled = true
    }

    public func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
        resolvedPrerequisite = missingPrerequisite
    }

    public func userDidTapApprove() {
        userDidTapApproveCalled = true
    }

    public func userDidTapDeny() {
        userDidTapDenyCalled = true
    }

    public func userDidTapCancel() {
        cancelPresentationCalled = true
        if shouldRequestCancelConfirmation {
            delegate?.orchestratorDidRequestCancelConfirmation()
        }
    }

    public func userDidConfirmCancel() {
        confirmCancelCalled = true
    }
}
#endif
