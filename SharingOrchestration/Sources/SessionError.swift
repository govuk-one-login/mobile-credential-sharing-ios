import Foundation
import SharingPrerequisiteGate

public indirect enum SessionError: LocalizedError, Equatable, Hashable, Sendable {
    case unrecoverablePrerequisite(MissingPrerequisite)
    // TODO: DCMAW-19716 Update to support both HolderSessionState and VerifierSessionState e.g. make the states conform to one protocol
    case incorrectSessionState(String)
    case unknown
    case generic(String)
    
    public var errorDescription: String? {
        switch self {
        case .unrecoverablePrerequisite(let missingPrerequisite):
            "Unrecoverable prerequisite: \(missingPrerequisite)"
        case .incorrectSessionState(let state):
            "Gated mutator function called from incorrect session state: \(state)"
        case .unknown:
            "Unknown error"
        case .generic(let description):
            description
        }
    }
}
