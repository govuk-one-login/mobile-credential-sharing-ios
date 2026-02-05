import Combine

// MARK: - HolderSession protocol

protocol HolderSessionProtocol {
    /// The current position of the User within the User journey.
    var currentState: AnyPublisher<HolderSessionState, Never> { get }

    /// Transition to a new state.
    func transition(to state: HolderSessionState) throws
}

// MARK: - HolderSession

final class HolderSession: HolderSessionProtocol {

    private let internalState: CurrentValueSubject<HolderSessionState, Never>

    init(initialState: HolderSessionState = .notStarted) {
        self.internalState = CurrentValueSubject(initialState)
    }

    var currentState: AnyPublisher<HolderSessionState, Never> {
        internalState.eraseToAnyPublisher()
    }

    func transition(to state: HolderSessionState) throws {
        let current = internalState.value
        guard current.canTransition(to: state) else {
            throw HolderSessionTransitionError.invalidTransition(
                from: current,
                to: state
            )
        }
        internalState.send(state)
    }
}
