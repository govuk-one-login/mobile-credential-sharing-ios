// MARK: - HolderSessionState

enum HolderSessionState: Equatable {

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

    // MARK: - Completion (terminal states)

    enum Completion: Equatable {
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
}

struct DeviceResponse: Equatable {
    let response: String // TODO: Define DeviceResponse
}

struct SessionError: Error, Equatable {
    let message: String // TODO: Define SessionError
}

// MARK: - State Transitions

extension HolderSessionState {

    /// Defines whether the current state can transition to the next state.
    func canTransition(to next: HolderSessionState) -> Bool {
        switch (self, next) {

        case (.notStarted, .preflight),
             (.notStarted, .complete): // check if this is valid
            return true

        case (.preflight, .readyToPresent),
             (.preflight, .complete):
            return true

        case (.readyToPresent, .presentingEngagement),
             (.readyToPresent, .complete):
            return true

        case (.presentingEngagement, .connecting),
             (.presentingEngagement, .complete):
            return true

        case (.connecting, .requestReceived),
             (.connecting, .complete):
            return true

        case (.requestReceived, .processingResponse),
             (.requestReceived, .complete):
            return true

        case (.processingResponse, .complete):
            return true

        default:
            return false
        }
    }
}

enum HolderSessionTransitionError: Error, Equatable {
    case invalidTransition(from: HolderSessionState, to: HolderSessionState)
}
