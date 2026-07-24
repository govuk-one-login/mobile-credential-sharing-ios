import Foundation
import SharingPrerequisiteGate

public indirect enum SessionError: LocalizedError, Equatable, Hashable, Sendable {
    case unrecoverablePrerequisite(MissingPrerequisite)
    // TODO: DCMAW-19716 Update to support both HolderSessionState and VerifierSessionState e.g. make the states conform to one protocol
    case incorrectSessionState(String)
    case sequencingViolation
    case policyViolation
    case invalidDeviceRequest
    case peerTermination
    case bleDisconnected
    case unknown
    case generic(String)
    
    public var errorDescription: String? {
        switch self {
        case .unrecoverablePrerequisite(let missingPrerequisite):
            "Unrecoverable prerequisite: \(missingPrerequisite)"
        case .incorrectSessionState(let state):
            "Gated mutator function called from incorrect session state: \(state)"
        case .sequencingViolation:
            "The current state did not expect the received data"
        case .policyViolation:
            "The received request does not meet policy requirements"
        case .invalidDeviceRequest:
            "The received Device Request is not valid"
        case .peerTermination:
            "The peer terminated the session"
        case .bleDisconnected:
            "Bluetooth disconnected"
        case .unknown:
            "Unknown error"
        case .generic(let description):
            description
        }
    }
}
