import Foundation

public enum CentralTransportError: Equatable, Error, LocalizedError {
    case serviceUUIDNotSet

    public var errorDescription: String? {
        switch self {
        case .serviceUUIDNotSet:
            return "serviceUUID not set on session"
        }
    }
}
