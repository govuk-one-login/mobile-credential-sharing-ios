import Foundation
import SharingPrerequisiteGate

@MainActor
public protocol HolderOrchestratorProtocol: AnyObject {
    var delegate: HolderOrchestratorDelegate? { get set }

    /// The verifier's identity to surface on the consent screen, when known.
    /// `nil` for flows without a remote verifier identifier (e.g. the ISO proximity flow).
    var verifierIdentifier: String? { get }

    func start()
    func resolve(_ missingPrerequisite: MissingPrerequisite)
    func userDidApprove()
    func userDidDeny()
    func cancel()
}

public protocol HolderOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: HolderSessionState?)
}
