import SharingBluetoothTransport
import SharingCryptoService
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
    public var messageCounter: Int = 1
    
    // BluetoothSessionProtocol variables
    /// Seperate serviceUUID visible to BluetoothSessionProtocol
    private(set) public var serviceUUID: UUID?
    private(set) public var connectionHandle: ConnectionHandle?

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
    public func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {
        guard self.currentState.kind == .readyToPresent else {
            throw HolderSessionTransitionError.invalidTransition(
                from: currentState
            )
        }
        self.cryptoContext = cryptoContext
        self.qrCode = qrCode
        self.serviceUUID = cryptoContext.serviceUUID
    }
    
    public func setSKDeviceKey(_ key: [UInt8]) throws {
        guard self.currentState.kind == .processingEstablishment else {
            throw HolderSessionTransitionError.invalidTransition(
                from: currentState
            )
        }
        self.cryptoContext?.skDeviceKey = key
    }
}

// MARK: - BluetoothSessionProtocol
extension HolderSession: BluetoothSessionProtocol {
    public func setConnection(_ connectionHandle: ConnectionHandle) throws {
        guard self.currentState.kind == .readyToPresent else {
            throw HolderSessionTransitionError.invalidTransition(
                from: currentState
            )
        }
        self.connectionHandle = connectionHandle
    }
}
