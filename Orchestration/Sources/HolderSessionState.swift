// MARK: - HolderSessionState

public enum HolderSessionState: Equatable, Hashable, Sendable {

    /// Null-value object declaring that a User hasn't started a journey yet.
    case notStarted

    /// Device is checking prerequisites for the journey.
    case preflight(missingPermissions: Set<String>)

    /// Device is ready to present encoded engagement data.
    case readyToPresent

    /// Device is actively presenting engagement data.
    case presentingEngagement

    /// Device is connecting to a verifier.
    case connecting

    /// A request has been received from the verifying device.
    case requestReceived

    /// User is generating the response proof.
    case processingResponse

    /// Terminal states for the journey.
    case complete(Completion)

    var kind: HolderSessionStateKind {
        switch self {
        case .notStarted: return .notStarted
        case .preflight: return .preflight
        case .readyToPresent: return .readyToPresent
        case .presentingEngagement: return .presentingEngagement
        case .connecting: return .connecting
        case .requestReceived: return .requestReceived
        case .processingResponse: return .processingResponse
        case .complete: return .complete
        }
    }

    var legalStateTransitions: [HolderSessionStateKind: [HolderSessionStateKind]] {
        [
            .notStarted: [.preflight, .complete],
            .preflight: [.readyToPresent, .complete],
            .readyToPresent: [.presentingEngagement, .complete],
            .presentingEngagement: [.connecting, .complete],
            .connecting: [.requestReceived, .complete],
            .requestReceived: [.processingResponse, .complete],
            .processingResponse: [.complete],
            .complete: []
        ]
    }
}

enum HolderSessionStateKind: Hashable {
    case notStarted
    case preflight
    case readyToPresent
    case presentingEngagement
    case connecting
    case requestReceived
    case processingResponse
    case complete
}

// MARK: - Completion (terminal states)

public enum Completion: Equatable, Hashable, Sendable {
    case success(DeviceResponse)
    case failed(SessionError)
    case cancelled

    var reason: String {
        switch self {
        case .success:
            return "Session completed successfully"
        case .failed(let error):
            return error.message
        case .cancelled:
            return "Session cancelled by User"
        }
    }
}

public struct DeviceResponse: Equatable, Hashable, Sendable {
    let response: String
}

public struct SessionError: Error, Equatable, Hashable {
    let message: String
}

// MARK: - State Transitions

extension HolderSessionState {
    /// Defines whether the current state can transition to the next state.
    func canTransition(to nextState: HolderSessionState) -> Bool {
        guard let transitions = legalStateTransitions[self.kind] else {
            print("Error: Missing transition entry for \(self.kind)")
            return false
        }
        return transitions.contains(nextState.kind)
    }
}

enum HolderSessionTransitionError: Error, Equatable {
    case invalidTransition(from: HolderSessionState, to: HolderSessionState)
}
