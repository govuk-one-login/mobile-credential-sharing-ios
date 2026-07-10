import Foundation
import SharingBluetoothTransport
import SharingCryptoService
import SharingPrerequisiteGate

@MainActor
public protocol VerifierOrchestratorProtocol {
    var delegate: VerifierOrchestratorDelegate? { get set }
    func startVerification(attributeGroup: AttributeGroup)
    func cancelVerification()
    func resolve(_ missingPrerequisite: MissingPrerequisite)
    func qrCodeScanned(_ qrCode: String)
}

public protocol VerifierOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: VerifierSessionState?)
}

@MainActor
public class VerifierOrchestrator: VerifierOrchestratorProtocol {
    /// Buffer between send-completion and GATT End to allow the peer time to receive and process the preceding SessionData.
    private static let gattEndDelay: Int = 500
    
    public weak var delegate: VerifierOrchestratorDelegate?
    private(set) var session: VerifierSessionProtocol?
    
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    private(set) var cryptoService: CryptoServiceProtocol?
    private(set) var bluetoothTransport: BluetoothTransportProtocol?
    private var sendCompletion: (() -> Void)?
    /// Set to `true` when the peer signals GATT End, indicating no further BLE writes are possible.
    private(set) var peerDidCloseTransport: Bool = false

    public init() {
        // Empty init required to declare class as public facing
    }

    init(
        prerequisiteGate: PrerequisiteGateProtocol? = nil,
        cryptoService: CryptoServiceProtocol? = nil,
        bluetoothTransport: BluetoothTransportProtocol? = nil
    ) {
        self.prerequisiteGate = prerequisiteGate
        self.cryptoService = cryptoService
        self.bluetoothTransport = bluetoothTransport
    }

    public func startVerification(attributeGroup: AttributeGroup) {
        let newSession = VerifierSession()
        session = newSession
        print("Verifier session started \(ObjectIdentifier(newSession))")

        // Convert the `AttributeGroup` into a `DocRequest` and set it on the session
        let docRequest = DocRequest(with: attributeGroup)
        do {
            try newSession.setDocRequest(docRequest)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
            return
        }
        
        performPreflightChecks()
    }

    func performPreflightChecks() {
        if prerequisiteGate == nil {
            prerequisiteGate = PrerequisiteGate()
        }
        guard let prerequisiteGate = prerequisiteGate else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("PrerequisiteGate is not available.")))
            return
        }
        do {
            let missingPrerequisites = prerequisiteGate.evaluatePrerequisites(
                for: Prerequisite.allCases
            ) {
                self.performPreflightChecks()
            }
            if missingPrerequisites.isEmpty {
                try session?.transition(to: .readyToScan)
                delegate?.orchestrator(didUpdateState: session?.currentState)
            } else {
                let bluetoothStateIsUnknown = missingPrerequisites.contains {
                    if case .bluetooth(.stateUnknown) = $0 { return true }
                    return false
                }

                // CBPeripheralManager has not fully initialised yet;
                // wait for the delegate to report a state change and re-run preflight checks
                guard !bluetoothStateIsUnknown else { return }

                if let unrecoverablePrerequisite = missingPrerequisites.first(where: { !$0.isRecoverable }) {
                    try session?.transition(
                        to: .failed(.unrecoverablePrerequisite(unrecoverablePrerequisite))
                    )
                    delegate?.orchestrator(didUpdateState: session?.currentState)
                    return
                }
                try session?.transition(
                    to: .preflight(missingPrerequisites: missingPrerequisites)
                )
                delegate?.orchestrator(didUpdateState: session?.currentState)
            }
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
        }
    }

    public func cancelVerification() {
        do {
            try session?.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        
        tearDownSession()
    }
    
    private func tearDownSession() {
        session = nil
        bluetoothTransport = nil
        prerequisiteGate = nil
        cryptoService = nil
        peerDidCloseTransport = false
        sendCompletion = nil
        print("Verifier session ended")
    }

    public func resolve(_ missingPrerequisite: MissingPrerequisite) {
        prerequisiteGate?.triggerResolution(for: missingPrerequisite)
    }
    
    public func qrCodeScanned(_ qrCode: String) {
        guard let session = getSession() else { return }
        
        // Ensure any duplicate QR scans are discarded by guarding the state
        guard session.currentState == .readyToScan else { return }
        
        do {
            try session.transition(to: .processingEngagement)
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            processQRCode(qrCode)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
        }
    }
    
    private func processQRCode(_ qrCode: String) {
        guard let session = getSession() else { return }
        
        let sessionDecryption = SessionDecryption()
        if cryptoService == nil {
            cryptoService = CryptoService(sessionDecryption: sessionDecryption)
        }
        
        do {
            try cryptoService?.processQRCode(qrCode, in: session)
            
            try session.transition(to: .connecting)
            delegate?.orchestrator(didUpdateState: session.currentState)

            startScanning(in: session)
        } catch {
            try? session.transition(to: .failed(.generic(error.localizedDescription)))
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            tearDownSession()
        }
    }
    
    func generateSessionEstablishment() {
        guard let session = getSession() else { return }
        
        do {
            let deviceRequest = try constructDeviceRequest(in: session)
            try cryptoService?.generateSessionEstablishment(
                with: deviceRequest,
                in: session
            )
            
            try bluetoothTransport?.startTransport()
            
            guard let sessionEstablishmentBytes = session.sessionEstablishmentBytes else {
                throw SessionError.generic("Session establishment bytes were not found on session.")
            }
            
            try bluetoothTransport?.send(sessionEstablishmentBytes)
        } catch {
            if error as? EncryptionError == .encryptionFailed {
                print("Encryption error due to malformed SKReader key")
            }
            
            try? session.transition(to: .failed(.generic(error.localizedDescription)))
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            tearDownSession()
        }
    }
    
    private func constructDeviceRequest(
        in session: VerifierSessionProtocol
    ) throws -> DeviceRequest {
        guard let docRequest = session.docRequest else {
            throw SessionError.generic("DocRequest was not found on session.")
        }
        
        let deviceRequest = DeviceRequest(docRequests: [docRequest])
        
        print("DeviceRequest: \(deviceRequest)")
        return deviceRequest
    }
            
    private func startScanning(in session: VerifierSessionProtocol) {
        if bluetoothTransport == nil {
            bluetoothTransport = BluetoothTransport()
            bluetoothTransport?.delegate = self
        }
        
        do {
            try bluetoothTransport?.connect(in: session)
            // TODO: DCMAW-17538 Send SessionEstablishment over BLE
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
        }
    }
    
    private func didReceive(_ messageData: Data) {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .verifying)
            delegate?.orchestrator(didUpdateState: .verifying)
                
            let sessionData = try cryptoService?.processResponse(messageData, in: session)
            print("SessionData decoded successfully. Status: \(sessionData?.status, default: "nil"), data (base64): \(sessionData?.data?.base64EncodedString() ?? "nil")")

            // TODO: DCMAW-19312 Implement DeviceResponse validation

            handleVerificationFailure(sessionData: sessionData)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
        }
    }
    
    // MARK: - Session Termination
    
    /// Routes verification failure to the correct termination path based on the inbound SessionData status
    /// and the current BLE connection state.

    private func handleVerificationFailure(sessionData: SessionData?) {
        let hasTerminalStatus = sessionData?.status == .sessionTermination
        
        if !hasTerminalStatus {
            // No status code — Verifier initiates full termination sequence
            sendTerminationMessage {
                self.performDelayedGATTEndAndTeardown()
            }
        } else if !peerDidCloseTransport {
            // Status 20 received + BLE still open — send GATT End only
            bluetoothTransport?.sendGattEnd()
            transitionToFailedAndTearDown()
        } else {
            // Status 20 received + BLE closed — no outbound signal
            transitionToFailedAndTearDown()
        }
    }
    
    /// Builds and sends a SessionData(status: 20) termination message via BLE.
    /// On send-completion, executes the provided closure (typically GATT End + teardown).
    private func sendTerminationMessage(completion: (() -> Void)? = nil) {
        guard let session = getSession() else { return }
        let terminationBytes = cryptoService?.buildTerminationMessage(in: session)
        
        if let terminationBytes {
            sendCompletion = completion
            bluetoothTransport?.sendSessionData(terminationBytes)
        }
        print("Termination message sent")
    }
    
    /// Waits 500ms after send-completion, then sends GATT End and tears down the session.
    private func performDelayedGATTEndAndTeardown() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.gattEndDelay))
            self.bluetoothTransport?.sendGattEnd()
            self.transitionToFailedAndTearDown()
        }
    }
    
    /// Transitions to .failed and destroys the session.
    private func transitionToFailedAndTearDown() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .failed(.generic("DeviceResponse validation failed")))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        tearDownSession()
    }
    
    private func getSession() -> VerifierSessionProtocol? {
        guard let session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return nil
        }
        return session
    }
}

// MARK: - BluetoothTransportDelegate
extension VerifierOrchestrator: @MainActor BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        print("Central manager powered on.")
    }

    public func bluetoothTransportDidStartAdvertising() {
        // Not used by Verifier
    }

    public func bluetoothTransportConnectionDidConnect() {
        generateSessionEstablishment()
    }

    public func bluetoothTransportDidDiscover() {
        print("Peripheral discovered, connection initiated.")
    }

    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        didReceive(messageData)
    }

    public func bluetoothTransportDidReceiveMessageEndRequest() {
        peerDidCloseTransport = true
    }

    public func bluetoothTransportDidFinishSending() {
        let completion = sendCompletion
        sendCompletion = nil
        completion?()
    }

    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
    }
}
