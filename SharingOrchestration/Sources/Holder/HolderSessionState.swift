import SharingCryptoService
import SharingPrerequisiteGate
import UIKit

// MARK: - SuccessReason

public enum SuccessReason: Equatable, Hashable, Sendable {
    /// Holder sent the response.
    case responseSent
    /// Holder denied consent — empty DeviceResponse sent.
    case denialResponse
    /// No matching document type, namespace, or attributes found — empty DeviceResponse sent.
    case emptyResponse
}

// MARK: - HolderSessionState

public indirect enum HolderSessionState: Equatable, Hashable, Sendable {

    /// Null-value object declaring that a User hasn't started a journey yet.
    case notStarted

    /// Device is checking prerequisites for the journey.
    case preflight(missingPrerequisites: [MissingPrerequisite])

    /// Device is ready to present encoded engagement data.
    case readyToPresent

    /// Device is actively presenting engagement data.
    case presentingEngagement(qrCode: UIImage)

    /// Device has established initial connection to a verifier
    case processingEstablishment

    /// A request has been received & validated, awaiting users conesnt to share.
    case awaitingUserConsent(DeviceRequest)

    /// User is generating the response proof.
    case processingResponse

    /// Response has been sent, awaiting Verifier's resolution signal.
    case awaitingVerifierResolution

    /// Session is in the process of terminating.
    case terminatingSession

    /// The journey was successful
    case success(reason: SuccessReason)
    
    /// There was an irrecoverable error
    case failed(SessionError)
    
    /// Journey has been cancelled by either Holder or Verifier
    case cancelled

    var kind: HolderSessionStateKind {
        switch self {
        case .notStarted: return .notStarted
        case .preflight: return .preflight
        case .readyToPresent: return .readyToPresent
        case .presentingEngagement: return .presentingEngagement
        case .processingEstablishment: return .processingEstablishment
        case .awaitingUserConsent: return .awaitingUserConsent
        case .processingResponse: return .processingResponse
        case .awaitingVerifierResolution: return .awaitingVerifierResolution
        case .terminatingSession: return .terminatingSession
        case .success: return .success
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }

    var legalStateTransitions: [HolderSessionStateKind: [HolderSessionStateKind]] {
        [
            .notStarted: [.preflight, .readyToPresent, .failed, .cancelled],
            .preflight: [.preflight, .readyToPresent, .failed, .cancelled],
            .readyToPresent: [.presentingEngagement, .failed, .cancelled],
            .presentingEngagement: [.processingEstablishment, .failed, .cancelled],
            .processingEstablishment: [.awaitingUserConsent, .success, .failed, .cancelled, .terminatingSession],
            .awaitingUserConsent: [.processingResponse, .failed, .cancelled, .terminatingSession],
            .processingResponse: [.awaitingVerifierResolution, .success, .failed, .cancelled, .terminatingSession],
            .awaitingVerifierResolution: [.success, .failed, .cancelled, .terminatingSession],
            .terminatingSession: [.success, .failed, .cancelled],
            .success: [],
            .failed: [],
            .cancelled: []
        ]
    }
}

enum HolderSessionStateKind: String, Hashable {
    case notStarted
    case preflight
    case readyToPresent
    case presentingEngagement
    case processingEstablishment
    case awaitingUserConsent
    case processingResponse
    case awaitingVerifierResolution
    case terminatingSession
    case success
    case failed
    case cancelled
}

// MARK: - State Transitions

extension HolderSessionState {
    /// Whether the session is in an active state where a transport failure is fatal.
    var isActiveState: Bool {
        switch kind {
        case .presentingEngagement, .processingEstablishment, .awaitingUserConsent, .processingResponse, .awaitingVerifierResolution:
            return true
        case .notStarted, .preflight, .readyToPresent, .terminatingSession, .success, .failed, .cancelled:
            return false
        }
    }

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
