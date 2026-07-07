import SharingCryptoService
import SharingValidationService

// MARK: - RemoteHolderSession protocol
public protocol RemoteHolderSessionProtocol: Sendable {
    var currentState: HolderSessionState { get }
    var validatedRequest: ValidatedRequest? { get }
    var deviceRequest: DeviceRequest? { get }

    func transition(to state: HolderSessionState) throws
    func setValidatedRequest(_ request: ValidatedRequest, deviceRequest: DeviceRequest) throws
}

// MARK: - RemoteHolderSession
/// In-flight state for the OID4VP (Remote) presentation flow. Mirrors `ISOHolderSession` but holds
/// the request-side artefacts (validated request + mapped `DeviceRequest`) rather than BLE/crypto engagement data.
public final class RemoteHolderSession: RemoteHolderSessionProtocol, @unchecked Sendable {
    public private(set) var currentState: HolderSessionState = .notStarted
    public private(set) var validatedRequest: ValidatedRequest?
    public private(set) var deviceRequest: DeviceRequest?

    init(_ initialState: HolderSessionState = .notStarted) {
        self.currentState = initialState
    }

    public func transition(to state: HolderSessionState) throws {
        guard currentState.canTransition(to: state) else {
            throw HolderSessionTransitionError.invalidTransition(from: currentState, to: state)
        }
        currentState = state
        print("State transitioned to: \(currentState)")
    }

    public func setValidatedRequest(_ request: ValidatedRequest, deviceRequest: DeviceRequest) throws {
        guard currentState.kind == .remoteValidatingRequest else {
            throw SessionError.incorrectSessionState(currentState.kind.rawValue)
        }
        self.validatedRequest = request
        self.deviceRequest = deviceRequest
    }
}
