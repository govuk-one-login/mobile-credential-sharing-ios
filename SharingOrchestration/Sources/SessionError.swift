import Foundation
import SharingPrerequisiteGate

public indirect enum SessionError: LocalizedError, Equatable, Hashable, Sendable {
    case unrecoverablePrerequisite(MissingPrerequisite)
    case incorrectSessionState(HolderSessionState)
    case unknown
    case generic(String)
    
    public var errorDescription: String {
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
