import SharingCryptoService
import SharingPrerequisiteGate
import UIKit

// MARK: - HolderSessionState

public enum HolderSessionState: Equatable, Hashable, Sendable {

    /// Null-value object declaring that a User hasn't started a journey yet.
    case notStarted

    /// Device is checking prerequisites for the journey.
    case preflight(missingPermissions: [Capability])

    /// Device is ready to present encoded engagement data.
    case readyToPresent

    /// Device is actively presenting engagement data.
    case presentingEngagement(qrCode: UIImage)

    /// Device has established initial connection to a verifier
    case processingEstablishment

    /// A request has been received from the verifying device.
    case requestReceived(DeviceRequest)

    /// User is generating the response proof.
    case processingResponse

    /// Terminal states for the journey.
    case complete(Completion)
    
    /// Journey has been cancelled by either Holder or Verifier
    case cancelled
    
    /// An error has been thrown
    case error(String)

    var kind: HolderSessionStateKind {
        switch self {
        case .notStarted: return .notStarted
        case .preflight: return .preflight
        case .readyToPresent: return .readyToPresent
        case .presentingEngagement: return .presentingEngagement
        case .processingEstablishment: return .processingEstablishment
        case .requestReceived: return .requestReceived
        case .processingResponse: return .processingResponse
        case .complete: return .complete
        case .cancelled: return .cancelled
        case .error: return .error
        }
    }

    var legalStateTransitions: [HolderSessionStateKind: [HolderSessionStateKind]] {
        [
            .notStarted: [.preflight, .readyToPresent, .complete, .cancelled],
            .preflight: [.preflight, .readyToPresent, .complete, .cancelled],
            .readyToPresent: [.presentingEngagement, .complete, .cancelled],
            .presentingEngagement: [.processingEstablishment, .complete, .cancelled],
            .processingEstablishment: [.requestReceived, .complete, .cancelled],
            .requestReceived: [.processingResponse, .complete, .cancelled],
            .processingResponse: [.complete, .cancelled],
            .complete: [],
            .cancelled: [],
            .error: []
        ]
    }
}

enum HolderSessionStateKind: Hashable {
    case notStarted
    case preflight
    case readyToPresent
    case presentingEngagement
    case processingEstablishment
    case requestReceived
    case processingResponse
    case complete
    case cancelled
    case error
}

// MARK: - Completion (terminal states)

public enum Completion: Equatable, Hashable, Sendable {
    case success(DeviceResponse)
    case failed(SessionError)

    var reason: String {
        switch self {
        case .success:
            return "Session completed successfully"
        case .failed(let error):
            return error.message
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
    case invalidTransition(from: HolderSessionState, to: HolderSessionState? = nil)
}
