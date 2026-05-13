import Foundation

public protocol VerifierOrchestratorProtocol {
    var delegate: VerifierOrchestratorDelegate? { get set }
    func startVerification()
    func cancelVerification()
}

public protocol VerifierOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: VerifierSessionState?)
}

public class VerifierOrchestrator: VerifierOrchestratorProtocol {
    public weak var delegate: VerifierOrchestratorDelegate?
    private(set) var session: VerifierSessionProtocol?

    public init() {
        // Empty init required to declare class public facing
    }

    public func startVerification() {
        session = VerifierSession()
        print("Verifier session started")
    }

    public func cancelVerification() {
        do {
            try session?.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
            // TODO: DCMAW-19714 Notify with .failed state once added to VerifierSessionState
            delegate?.orchestrator(didUpdateState: .cancelled)
        }
        session = nil
        print("Verifier session ended")
    }
}
