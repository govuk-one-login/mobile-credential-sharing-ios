import SharingCryptoService
import SharingPrerequisiteGate
import UIKit

// MARK: - HolderSessionState

public enum HolderSessionState: Equatable, Hashable, Sendable {

    /// Null-value object declaring that a User hasn't started a journey yet.
    case notStarted

    /// Device is checking prerequisites for the journey.
    case preflight(missingPrerequisites: [MissingPrerequisite])

    // ISO-specific states
    /// Device is ready to present encoded engagement data.
    case isoReadyToPresent

    /// Device is actively presenting engagement data.
    case isoPresentingEngagement(qrCode: UIImage)

    /// Device has established initial connection to a verifier
    case isoProcessingEstablishment

    // Common states
    /// A request has been received & validated, awaiting users consent to share.
    case awaitingUserConsent(DeviceRequest)

    /// User is generating the response proof.
    case processingResponse

    /// The journey was successful
    case success

    /// There was an irrecoverable error
    case failed(SessionError)

    /// Journey has been cancelled by either Holder or Verifier
    case cancelled

    var kind: HolderSessionStateKind {
        switch self {
        case .notStarted: return .notStarted
        case .preflight: return .preflight
        case .isoReadyToPresent: return .isoReadyToPresent
        case .isoPresentingEngagement: return .isoPresentingEngagement
        case .isoProcessingEstablishment: return .isoProcessingEstablishment
        case .awaitingUserConsent: return .awaitingUserConsent
        case .processingResponse: return .processingResponse
        case .success: return .success
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }

    var legalStateTransitions: [HolderSessionStateKind: [HolderSessionStateKind]] {
        [
            .notStarted: [.preflight, .isoReadyToPresent, .failed, .cancelled],
            .preflight: [.preflight, .isoReadyToPresent, .failed, .cancelled],
            .isoReadyToPresent: [.isoPresentingEngagement, .failed, .cancelled],
            .isoPresentingEngagement: [.isoProcessingEstablishment, .failed, .cancelled],
            .isoProcessingEstablishment: [.awaitingUserConsent, .failed, .cancelled],
            .awaitingUserConsent: [.processingResponse, .failed, .cancelled],
            .processingResponse: [.success, .failed, .cancelled],
            .success: [],
            .failed: [],
            .cancelled: []
        ]
    }
}

enum HolderSessionStateKind: String, Hashable {
    case notStarted
    case preflight
    case isoReadyToPresent
    case isoPresentingEngagement
    case isoProcessingEstablishment
    case awaitingUserConsent
    case processingResponse
    case success
    case failed
    case cancelled
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

enum HolderSessionTransitionError: LocalizedError, Equatable {
    case invalidTransition(from: HolderSessionState, to: HolderSessionState? = nil)

    var errorDescription: String? {
        switch self {
        case .invalidTransition(from: let from, to: let to):
            return "Invalid state transition: \(from.kind.rawValue) -> \(to?.kind.rawValue ?? "nil")"
        }
    }
}
