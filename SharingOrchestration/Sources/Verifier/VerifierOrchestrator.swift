import Foundation

public protocol VerifierOrchestratorProtocol {
    var delegate: VerifierOrchestratorDelegate? { get set }
    func startVerification()
    func cancelVerification()
}

public protocol VerifierOrchestratorDelegate: AnyObject {
    // TODO: DCMAW-18160 Update String type to SessionState
    func orchestrator(didUpdateState: String)
}

public class VerifierOrchestrator: VerifierOrchestratorProtocol {
    public weak var delegate: VerifierOrchestratorDelegate?

    public init() {
        // Empty init required to declare class public facing
    }

    public func startVerification() {
        print("Verifier journey started")
    }

    public func cancelVerification() {
        print("Verifier journey cancelled")
    }
}
