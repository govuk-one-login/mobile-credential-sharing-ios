import SharingBluetoothTransport
import SharingCryptoService
import UIKit

// MARK: - ISOHolderSession protocol
public protocol ISOHolderSessionProtocol: CryptoHolderSessionProtocol, BluetoothSessionProtocol, CredentialSessionProtocol, Sendable {
    /// The current position of the User within the User journey.
    var currentState: HolderSessionState { get }

    /// Transition to a new state.
    func transition(to state: HolderSessionState) throws
}

// MARK: - ISOHolderSession
public final class ISOHolderSession: ISOHolderSessionProtocol, Equatable, @unchecked Sendable {
    public var currentState: HolderSessionState = .notStarted
    
    // CryptoHolderSessionProtocol variables
    private(set) public var cryptoContext: CryptoContext?
    private(set) public var qrCode: UIImage?
    public var skReaderMessageCounter: Int = 1
    public var skDeviceMessageCounter: Int = 1
    private(set) public var sessionTranscript: SessionTranscript?
    private(set) public var docType: DocType?
    private(set) public var deviceAuthenticationBytes: Data?
    private(set) public var signatureBytes: Data?
    private(set) public var deviceSigned: DeviceSigned?
    
    // BluetoothSessionProtocol variables
    /// Seperate serviceUUID visible to BluetoothSessionProtocol
    private(set) public var serviceUUID: UUID?
    private(set) public var connectionHandle: ConnectionHandle?
    
    // CredentialSessionProtocol variables
    private(set) public var matchedCredential: Credential?
    private(set) public var issuerSigned: IssuerSigned?

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
        print("State transitioned to: \(currentState)")
    }

    public static func == (lhs: ISOHolderSession, rhs: ISOHolderSession) -> Bool {
        lhs.currentState == rhs.currentState
    }
}

// MARK: - CryptoHolderSessionProtocol
extension ISOHolderSession: CryptoHolderSessionProtocol {
    public func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {
        guard self.currentState.kind == .isoReadyToPresent else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.cryptoContext = cryptoContext
        self.qrCode = qrCode
        self.serviceUUID = cryptoContext.serviceUUID
    }
    
    public func setSKDeviceKey(_ key: [UInt8]) throws {
        guard self.currentState.kind == .isoProcessingEstablishment else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.cryptoContext?.skDeviceKey = key
    }
    
    public func setSessionTranscriptAndDocType(
        sessionTranscript: SessionTranscript,
        docType: DocType
    ) throws {
        guard self.currentState.kind == .isoProcessingEstablishment else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.sessionTranscript = sessionTranscript
        self.docType = docType
    }
    
    public func setDeviceAuthenticationBytes(_ bytes: Data) throws {
        guard self.currentState.kind == .processingResponse else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.deviceAuthenticationBytes = bytes
    }

    public func setSignatureBytes(_ bytes: Data) throws {
        guard self.currentState.kind == .processingResponse else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.signatureBytes = bytes
    }

    public func setDeviceSigned(deviceSigned: DeviceSigned) throws {
        guard self.currentState.kind == .processingResponse else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.deviceSigned = deviceSigned
    }

}

// MARK: - BluetoothSessionProtocol
extension ISOHolderSession: BluetoothSessionProtocol {
    public func setConnection(_ connectionHandle: ConnectionHandle) throws {
        guard self.currentState.kind == .isoReadyToPresent else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.connectionHandle = connectionHandle
    }
}

// MARK: - CredentialSessionProtocol
extension ISOHolderSession: CredentialSessionProtocol {
    public func setMatchedCredential(
        _ credential: Credential
    ) throws {
        guard self.currentState.kind == .isoProcessingEstablishment else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        
        self.matchedCredential = credential
    }
    
    public func setIssuerSigned(_ issuerSigned: SharingCryptoService.IssuerSigned) throws {
        guard self.currentState.kind == .isoProcessingEstablishment else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        
        self.issuerSigned = issuerSigned
    }
}
