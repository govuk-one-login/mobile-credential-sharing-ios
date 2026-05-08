import Foundation

public protocol VerifierOrchestratorProtocol {
    var delegate: VerifierOrchestratorDelegate? { get set }
    func startVerification()
    func cancelVerification()
}

public protocol VerifierOrchestratorDelegate: AnyObject {
    func verifierOrchestrator(didStart: Bool)
    func verifierOrchestrator(didCancel: Bool)
}

public class VerifierOrchestrator: VerifierOrchestratorProtocol {
    public weak var delegate: VerifierOrchestratorDelegate?
    private(set) public var isActive: Bool = false

    public init() {
        // Empty init required to declare class public facing
    }

    public func startVerification() {
        isActive = true
        print("Verifier journey started")
        delegate?.verifierOrchestrator(didStart: true)
    }

    public func cancelVerification() {
        isActive = false
        print("Verifier journey cancelled")
        delegate?.verifierOrchestrator(didCancel: true)
    }
}
