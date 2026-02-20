import CryptoService
import UIKit

// MARK: - HolderSession protocol
public protocol HolderSessionProtocol: CryptoSessionProtocol {
    /// The current position of the User within the User journey.
    var currentState: HolderSessionState { get }

    /// Transition to a new state.
    func transition(to state: HolderSessionState) throws
}

// MARK: - HolderSession
public final class HolderSession: HolderSessionProtocol, Equatable {

    public var currentState: HolderSessionState = .notStarted
    
    public var cryptoContext: CryptoContext?
    public var qrCode: UIImage?

    init(_ initialState: HolderSessionState = .notStarted) {
        self.currentState = initialState
    }

    public func transition(to state: HolderSessionState) throws {
        guard currentState.canTransition(to: state) else {
            throw HolderSessionTransitionError.invalidTransition(
                from: currentState,
                to: state
            )
        }
        currentState = state
    }

    public static func == (lhs: HolderSession, rhs: HolderSession) -> Bool {
        lhs.currentState == rhs.currentState
    }
}

extension HolderSession: CryptoSessionProtocol {}
