import Foundation

public enum NetworkTransportError: LocalizedError, Equatable, Sendable {
    case encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let detail):
            "Encoding failed: \(detail)"
        }
    }
}
