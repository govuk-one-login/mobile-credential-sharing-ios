#if DEBUG
import SharingOrchestration
import SharingPrerequisiteGate

public class MockHolderOrchestrator: HolderOrchestratorProtocol {
    public weak var delegate: (any HolderOrchestratorDelegate)?

    public var session: HolderSession?
    public var startPresentationCalled = false
    public var cancelPresentationCalled = false
    public var resolveCalled = false
    public var resolvedPrerequisite: MissingPrerequisite?
    public var userDidTapApproveCalled = false
    public var userDidTapDenyCalled = false
    public var qrCodeGenerationDidFailCalled = false

    public init() {}

    public func startTransaction() {
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
    }

    public func qrCodeGenerationDidFail() {
        qrCodeGenerationDidFailCalled = true
    }
}
#endif
