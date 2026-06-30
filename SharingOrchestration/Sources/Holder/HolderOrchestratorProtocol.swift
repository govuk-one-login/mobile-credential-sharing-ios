import Foundation
import SharingPrerequisiteGate

@MainActor
public protocol HolderOrchestratorProtocol: AnyObject {
    var delegate: HolderOrchestratorDelegate? { get set }
    func start()
    func resolve(_ missingPrerequisite: MissingPrerequisite)
    func userDidApprove()
    func userDidDeny()
    func cancel()
}

public protocol HolderOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: HolderSessionState?)
}
