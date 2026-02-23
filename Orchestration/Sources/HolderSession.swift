import BluetoothTransport
import CryptoService
import UIKit

// MARK: - HolderSession protocol
public protocol HolderSessionProtocol: CryptoSessionProtocol, BluetoothSessionProtocol {
    /// The current position of the User within the User journey.
    var currentState: HolderSessionState { get }

    /// Transition to a new state.
    func transition(to state: HolderSessionState) throws
}

// MARK: - HolderSession
public final class HolderSession: HolderSessionProtocol, Equatable {
    public var currentState: HolderSessionState = .notStarted
    
    // CryptoSessionProtocol variables
    private(set) public var cryptoContext: CryptoContext?
    private(set) public var qrCode: UIImage?
    
    // BluetoothSessionProtocol variables
    private(set) public var serviceUUID: UUID?

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

// MARK: - CryptoSessionProtocol
extension HolderSession: CryptoSessionProtocol {
    public func setEngagement(crytoContext: CryptoContext, qrCode: UIImage) throws {
        guard self.currentState == .readyToPresent else {
            throw HolderSessionTransitionError.invalidTransition(
                from: currentState
            )
        }
        self.cryptoContext = crytoContext
        self.qrCode = qrCode
    }
}

// MARK: - BluetoothSessionProtocol
extension HolderSession: BluetoothSessionProtocol {
    public func setConnection(serviceUUID: UUID) throws {
        guard self.currentState == .readyToPresent else {
            throw HolderSessionTransitionError.invalidTransition(
                from: currentState
            )
        }
        self.serviceUUID = serviceUUID
    }
}
