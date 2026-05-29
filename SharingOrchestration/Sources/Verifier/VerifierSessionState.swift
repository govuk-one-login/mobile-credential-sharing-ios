import Foundation
import SharingPrerequisiteGate

// MARK: - VerifierSessionState

public enum VerifierSessionState: Equatable, Hashable, Sendable {

    /// Null-value object declaring that a User hasn't started a journey yet.
    case notStarted

    /// Device is checking prerequisites for the journey.
    case preflight(missingPrerequisites: [MissingPrerequisite])

    /// All prerequisites are satisfied; device is ready to scan a QR code.
    case readyToScan
    
    /// A valid QR 'mdoc' code has been scanned; device engagement is being processed
    case processingEngagement

    /// There was an irrecoverable error
    case failed(SessionError)

    /// Journey has been cancelled by the Verifier
    case cancelled

    var kind: VerifierSessionStateKind {
        switch self {
        case .notStarted: return .notStarted
        case .preflight: return .preflight
        case .readyToScan: return .readyToScan
        case .processingEngagement: return .processingEngagement
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }

    var legalStateTransitions: [VerifierSessionStateKind: [VerifierSessionStateKind]] {
        [
            .notStarted: [.preflight, .readyToScan, .failed, .cancelled],
            .preflight: [.preflight, .readyToScan, .failed, .cancelled],
            .readyToScan: [.processingEngagement, .failed, .cancelled],
            .processingEngagement: [.failed, .cancelled],
            .failed: [],
            .cancelled: []
        ]
    }
}

enum VerifierSessionStateKind: String, Hashable {
    case notStarted
    case preflight
    case readyToScan
    case processingEngagement
    case failed
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
