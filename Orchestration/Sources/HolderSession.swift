// MARK: - HolderSession protocol

protocol HolderSessionProtocol {
    /// The current position of the User within the User journey.
    var currentState: HolderSessionState { get }

    /// Transition to a new state.
    func transition(to state: HolderSessionState) throws
}

// MARK: - HolderSession

final class HolderSession: HolderSessionProtocol, Equatable {

    var currentState: HolderSessionState = .notStarted

    init(_ initialState: HolderSessionState = .notStarted) {
        self.currentState = initialState
    }

    func transition(to state: HolderSessionState) throws {
        let current = currentState
        guard current.canTransition(to: state) else {
            throw HolderSessionTransitionError.invalidTransition(
                from: current,
                to: state
            )
        }
        currentState = state
    }

    static func == (lhs: HolderSession, rhs: HolderSession) -> Bool {
        lhs.currentState == rhs.currentState
    }
}
