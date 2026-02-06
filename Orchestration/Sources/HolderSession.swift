// MARK: - HolderSession protocol

public protocol HolderSessionProtocol {
    /// The current position of the User within the User journey.
    var currentState: HolderSessionState { get }

    /// Transition to a new state.
    func transition(to state: HolderSessionState) throws
}

// MARK: - HolderSession

public final class HolderSession: HolderSessionProtocol, Equatable {

    public var currentState: HolderSessionState = .notStarted

    init(_ initialState: HolderSessionState = .notStarted) {
        self.currentState = initialState
    }

    public func transition(to state: HolderSessionState) throws {
        let current = currentState
        guard current.canTransition(to: state) else {
            throw HolderSessionTransitionError.invalidTransition(
                from: current,
                to: state
            )
        }
        currentState = state
    }

    public static func == (lhs: HolderSession, rhs: HolderSession) -> Bool {
        lhs.currentState == rhs.currentState
    }
}
