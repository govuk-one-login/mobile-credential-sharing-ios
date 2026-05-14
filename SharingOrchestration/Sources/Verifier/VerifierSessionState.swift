import Foundation

// MARK: - VerifierSessionState

public enum VerifierSessionState: Equatable, Hashable, Sendable {

    /// Null-value object declaring that a User hasn't started a journey yet.
    case notStarted

    /// Journey has been cancelled by the Verifier
    case cancelled

    var kind: VerifierSessionStateKind {
        switch self {
        case .notStarted: return .notStarted
        case .cancelled: return .cancelled
        }
    }

    var legalStateTransitions: [VerifierSessionStateKind: [VerifierSessionStateKind]] {
        [
            .notStarted: [.cancelled],
            .cancelled: []
        ]
    }
}

enum VerifierSessionStateKind: Hashable {
    case notStarted
    case cancelled
}

// MARK: - State Transitions

extension VerifierSessionState {
    /// Defines whether the current state can transition to the next state.
    func canTransition(to nextState: VerifierSessionState) -> Bool {
        guard let transitions = legalStateTransitions[self.kind] else {
            return false
        }
        return transitions.contains(nextState.kind)
    }
}

enum VerifierSessionTransitionError: Error, Equatable {
    case invalidTransition(from: VerifierSessionState, to: VerifierSessionState? = nil)
}
