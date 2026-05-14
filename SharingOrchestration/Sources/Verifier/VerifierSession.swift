import Foundation

// MARK: - VerifierSession protocol
public protocol VerifierSessionProtocol: Sendable {
    /// The current position of the User within the verifier journey.
    var currentState: VerifierSessionState { get }

    /// Transition to a new state.
    func transition(to state: VerifierSessionState) throws
}

// MARK: - VerifierSession
public final class VerifierSession: VerifierSessionProtocol, Equatable, @unchecked Sendable {
    public private(set) var currentState: VerifierSessionState = .notStarted

    init(_ initialState: VerifierSessionState = .notStarted) {
        self.currentState = initialState
    }

    public func transition(to state: VerifierSessionState) throws {
        guard currentState.canTransition(to: state) else {
            throw VerifierSessionTransitionError.invalidTransition(
                from: currentState,
                to: state
            )
        }
        currentState = state
    }

    public static func == (lhs: VerifierSession, rhs: VerifierSession) -> Bool {
        lhs.currentState == rhs.currentState
    }
}
