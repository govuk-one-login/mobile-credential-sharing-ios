// MARK: - HolderSession protocol

protocol HolderSessionProtocol {
    /// The current position of the User within the User journey.
    var currentState: HolderSessionState { get }

    /// Transition to a new state.
    func transition(to state: HolderSessionState) throws
}

// MARK: - HolderSession

final class HolderSession: HolderSessionProtocol {

    init(_ initialState: HolderSessionState = .notStarted) {
        self.currentState = initialState
    }

    var currentState: HolderSessionState = .notStarted

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
}
