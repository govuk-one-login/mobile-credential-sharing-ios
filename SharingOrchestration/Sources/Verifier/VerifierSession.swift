import Foundation
import SharingBluetoothTransport
import SharingCryptoService

// MARK: - VerifierSession protocol
public protocol VerifierSessionProtocol: CryptoVerifierSessionProtocol, BluetoothSessionProtocol, Sendable {
    /// The current position of the User within the verifier journey.
    var currentState: VerifierSessionState { get }

    /// Transition to a new state.
    func transition(to state: VerifierSessionState) throws
}

// MARK: - VerifierSession
public final class VerifierSession: VerifierSessionProtocol, Equatable, @unchecked Sendable {
    
    public private(set) var currentState: VerifierSessionState = .notStarted
    
    // CryptoVerifierSessionProtocol variables
    private(set) public var cryptoContext: CryptoContext?
    private(set) public var serviceUUID: UUID?

    init(_ initialState: VerifierSessionState = .notStarted) {
        self.currentState = initialState
    }

    public func transition(to state: VerifierSessionState) throws {
        guard currentState.canTransition(to: state) else {
            throw VerifierSessionTransitionError.invalidTransition(
                from: currentState,
                to: state
            )
        }
        currentState = state
        print("State transitioned to: \(currentState)")
    }

    public static func == (lhs: VerifierSession, rhs: VerifierSession) -> Bool {
        lhs.currentState == rhs.currentState
    }
}

extension VerifierSession: CryptoVerifierSessionProtocol {
    public func setEngagement(cryptoContext: CryptoContext) throws {
        guard self.currentState.kind == .processingEngagement else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.cryptoContext = cryptoContext
        self.serviceUUID = cryptoContext.serviceUUID
    }
}

// MARK: - BluetoothSessionProtocol
extension VerifierSession: BluetoothSessionProtocol {
    public var connectionHandle: ConnectionHandle? { nil }
    public func setConnection(_ connectionHandle: ConnectionHandle) throws {
        // TODO: DCMAW-17183 Not currently used by Verifier but explore use case for both peripheral/central
    }
}
