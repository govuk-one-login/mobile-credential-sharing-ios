import Foundation
import SharingBluetoothTransport
import SharingCryptoService
import SharingLogging
import SharingPrerequisiteGate

// swiftlint:disable file_length
@MainActor
public protocol VerifierOrchestratorProtocol {
    var delegate: VerifierOrchestratorDelegate? { get set }
    func startVerification(config: VerifierConfig)
    func cancelVerification()
    func userDidConfirmCancel()
    func resolve(_ missingPrerequisite: MissingPrerequisite)
    func qrCodeScanned(_ qrCode: String)
}

public protocol VerifierOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: VerifierSessionState?)
    func orchestratorDidRequestCancelConfirmation()
}

// swiftlint:disable:next type_body_length
public class VerifierOrchestrator: VerifierOrchestratorProtocol {
    /// Buffer between send-completion and GATT End to allow the peer time to receive and process the preceding SessionData.
    private static let defaultGattEndDelay: Int = 500
    
    public weak var delegate: VerifierOrchestratorDelegate?
    private(set) var session: VerifierSessionProtocol?
    
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    private(set) var cryptoService: CryptoServiceProtocol?
    private(set) var bluetoothTransport: BluetoothTransportProtocol?
    private(set) var inactivityTimer: InactivityTimerProtocol?
    private var sendCompletion: (() -> Void)?
    private let gattEndDelay: Int
    
    /// Tracks whether a connection loss (GATT End or BLE disconnect) occurred during validation.
    /// When `true`, the termination sequence skips outbound signals since the transport is already closed.
    var connectionLost: Bool = false

    public init() {
        self.gattEndDelay = Self.defaultGattEndDelay
    }

    init(
        prerequisiteGate: PrerequisiteGateProtocol? = nil,
        cryptoService: CryptoServiceProtocol? = nil,
        bluetoothTransport: BluetoothTransportProtocol? = nil,
        gattEndDelay: Int = defaultGattEndDelay,
        inactivityTimer: InactivityTimerProtocol? = nil) {
        self.prerequisiteGate = prerequisiteGate
        self.cryptoService = cryptoService
        self.bluetoothTransport = bluetoothTransport
        self.gattEndDelay = gattEndDelay
        self.inactivityTimer = inactivityTimer
    }

    public func startVerification(config: VerifierConfig) {
        let newSession = VerifierSession()
        session = newSession
        OSLoggingService.shared.logEvent(LoggingEvents.verifierSessionStarted,
                                         parameters: ["newSession": newSession])

        // Route the trusted issuer certificate to the session (verification component)
        do {
            try newSession.setTrustedIssuerCertificate(config.trustedIssuerCertificate)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
            return
        }

        // Route the attribute request to the orchestration layer via DocRequest
        let docRequest = DocRequest(with: config.attributeRequest)
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
                self.prerequisiteGate = nil
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
        guard let session else { return }

        switch session.currentState.kind {
        // Active BLE connection — show confirmation dialog
        case .connecting, .verifying:
            delegate?.orchestratorDidRequestCancelConfirmation()

        // No BLE connection — cancel immediately without confirmation
        case .notStarted, .preflight, .readyToScan, .processingEngagement:
            do {
                try session.transition(to: .cancelled)
                delegate?.orchestrator(didUpdateState: session.currentState)
            } catch {
                delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            }
            tearDownSession()

        // Terminal or terminating states — no-op
        case .terminatingSession, .success, .failed, .cancelled:
            break
        }
    }

    public func userDidConfirmCancel() {
        guard session != nil else { return }
        // User confirmed — send GATT End only (no SessionData), then cancel
        if bluetoothTransport?.isConnected == true {
            bluetoothTransport?.sendGattEnd()
        }
        transitionToTerminalStateAndTeardown(terminalState: .cancelled)
    }
    
    private func tearDownSession(andNotify: Bool = false) {
        guard session != nil else { return }
        inactivityTimer?.stop()
        inactivityTimer = nil
        if andNotify {
            session?.connectionHandle?.notify = true
        }
        session = nil
        bluetoothTransport = nil
        prerequisiteGate = nil
        cryptoService = nil
        sendCompletion = nil
        connectionLost = false
        OSLoggingService.shared.logEvent(LoggingEvents.verifierSessionEnded)
    }
    
    private func transitionToCancel() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
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
            
            bluetoothTransport?.startTransport()
        } catch {
            if error as? EncryptionError == .encryptionFailed {
                OSLoggingService.shared.logEvent(LoggingEvents.encryptionErrorMalformedSKReader)
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
        OSLoggingService.shared.logEvent(LoggingEvents.deviceRequest,
                                         parameters: ["request": deviceRequest])
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
    
    private func sendSessionEstablishment() {
        guard let session = getSession() else { return }
        
        do {
            guard let sessionEstablishmentBytes = session.sessionEstablishmentBytes else {
                throw SessionError.generic("Session establishment bytes were not found on session.")
            }
            
            bluetoothTransport?.send(sessionEstablishmentBytes)
        } catch {
            try? session.transition(to: .failed(.generic(error.localizedDescription)))
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            tearDownSession()
        }
    }
    
    // MARK: - Connecting State Validation
    
    /// Validates inbound BLE messages while in the `connecting` state.
    /// Routes to termination if the message is not a valid SessionData,
    /// is a malformed SessionData, or contains data with a non-20 status.
    private func handleMessageInConnecting(_ messageData: Data) {
        // Step 1: Attempt to decode as SessionData
        let sessionData: SessionData
        do {
            sessionData = try SessionData(fromCBOR: messageData)
        } catch {
            // Not a valid SessionData — initiate full termination
            initiateTermination(sessionData: nil, reason: .sequencingViolation("Invalid message received in connecting state"))
            return
        }
        
        // Step 2: Non-20 status code present
        if let status = sessionData.status,
           status != .sessionTermination {
            handleNon20Status()
            return
        }
        
        // Step 3: Status-only SessionData (peer termination signal)
        if sessionData.data == nil, sessionData.status != nil {
            handlePeerTerminationInConnecting()
            return
        }
        
        // Step 4: Neither status nor data present
        if sessionData.status == nil && sessionData.data == nil {
            initiateTermination(sessionData: nil, reason: .sequencingViolation("Malformed SessionData received in connecting state"))
            return
        }
        
        // Valid SessionData — proceed to normal processing
        didReceive(messageData)
    }
    
    /// Data present with non-20 status - do not process data, send only GATT End, no SessionData(20).
    private func handleNon20Status() {
        guard let session = getSession() else { return }
        
        do {
            try session.transition(to: .failed(.protocolError))
            bluetoothTransport?.sendGattEnd()
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        tearDownSession()
    }
    
    /// Handles a status-only SessionData arriving while in `connecting`.
    /// No outbound signal is sent (no GATT End, no termination message).
    /// Transitions directly to failed and destroys the session.
    private func handlePeerTerminationInConnecting() {
        guard let session = getSession() else { return }
        
        do {
            try session.transition(to: .failed(.peerTermination))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        tearDownSession()
    }
    
    private func didReceive(_ messageData: Data) {
        guard let session = getSession() else { return }
        var sessionData: SessionData?
        
        do {
            try session.transition(to: .verifying)
            delegate?.orchestrator(didUpdateState: .verifying)
                
            sessionData = try cryptoService?.processResponse(messageData, in: session)
            OSLoggingService.shared.logEvent(LoggingEvents.sessionDataDecodedSuccessfully,
                                             parameters: ["Status": sessionData?.status ?? "nil"])

            guard let decryptedData = sessionData?.data else {
                initiateTermination(sessionData: sessionData, reason: .generic("No data payload received"))
                return
            }
            
            let deviceResponse = try DeviceResponse(data: decryptedData)
            OSLoggingService.shared.logEvent(LoggingEvents.deviceResponseParsedSuccessfully,
                                             parameters: ["Version": deviceResponse.version,
                                                          "documents": deviceResponse.documents?.count ?? 0])
            
            // Validation succeeded — route through termination with success outcome
            initiateTermination(sessionData: sessionData, terminalState: .success(deviceResponse))
        } catch let error as DeviceResponseError {
            // Validation failed — route through termination handler
            OSLoggingService.shared.logEvent(LoggingEvents.deviceResponseValidationFailed,
                                             parameters: ["error": error.localizedDescription])
            initiateTermination(sessionData: sessionData, reason: .generic(error.localizedDescription))
        } catch {
            // Decryption/session error — immediate fail
            OSLoggingService.shared.logEvent(LoggingEvents.sessionDecyrptionError,
                                             parameters: ["error": error.localizedDescription])
            try? session.transition(to: .failed(.generic(error.localizedDescription)))
            delegate?.orchestrator(didUpdateState: session.currentState)
            tearDownSession()
        }
    }
    
    // MARK: - Connection Loss (GATT End / raw BLE disconnect)

    /// Handles both GATT `End` and raw BLE disconnects (device out of range, Bluetooth toggled off,
    /// BLE permission revoked, remote device powered off, remote app force-killed, etc.)
    /// Behaviour is determined by the current session state:
    /// - Fatal (connecting): `.failed(terminalError)` + BLE disconnected screen + destroy session
    /// - Non-interrupting (verifying): validation continues uninterrupted; outcome per validation result
    /// - Already terminal (success, failed, cancelled): no-op
    /// - During ordered teardown (terminatingSession): suppress inbound signal
    private func handleConnectionLoss(_ terminalError: SessionError) {
        guard let session else { return }

        switch session.currentState.kind {
        // During ordered teardown — suppress
        case .terminatingSession:
            break

        // Already terminal — no-op
        case .success, .failed, .cancelled:
            break

        // Verifying — non-interrupting, validation continues
        case .verifying:
            connectionLost = true

        // Connecting or pre-connection — fatal
        case .connecting, .processingEngagement, .readyToScan, .preflight, .notStarted:
            sendCompletion = nil
            do {
                try session.transition(to: .failed(terminalError))
                delegate?.orchestrator(didUpdateState: session.currentState)
            } catch {
                delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            }
            tearDownSession()
        }
    }

    // MARK: - Session Termination
    
    /// Initiates ordered teardown, sealing the terminal outcome and routing
    /// the termination sequence based on the inbound SessionData status and BLE connection state.
    private func initiateTermination(sessionData: SessionData?, reason: SessionError) {
        initiateTermination(sessionData: sessionData, terminalState: .failed(reason))
    }
    
    /// Initiates ordered teardown, sealing the terminal outcome and routing
    /// the termination sequence based on the inbound SessionData status and BLE connection state.
    private func initiateTermination(sessionData: SessionData?, terminalState: VerifierSessionState) {
        guard let session = getSession() else { return }
        
        do {
            try session.transition(to: .terminatingSession)
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
            return
        }
        
        // Connection already lost (GATT End / BLE disconnect arrived during validation).
        // Skip all outbound signals — transport is closed. Transition directly to terminal state.
        if connectionLost {
            transitionToTerminalStateAndTeardown(terminalState: terminalState)
            return
        }
        
        if sessionData?.status == .sessionTermination {
            // Peer initiated termination — don't send status 20 back
            if bluetoothTransport?.isConnected == true {
                bluetoothTransport?.sendGattEnd()
            }
            transitionToTerminalStateAndTeardown(terminalState: terminalState)
        } else {
            // No status code — Verifier initiates full termination sequence
            sendTerminationMessage {
                self.performDelayedGATTEndAndTeardown(terminalState: terminalState)
            }
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
        OSLoggingService.shared.logEvent(LoggingEvents.terminationMessageSent)
    }
    
    /// Waits `gattEndDelay` ms after send-completion, then sends GATT End and tears down the session.
    private func performDelayedGATTEndAndTeardown(terminalState: VerifierSessionState) {
        let delay = gattEndDelay
        if delay > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(delay))
                self.bluetoothTransport?.sendGattEnd()
                self.transitionToTerminalStateAndTeardown(terminalState: terminalState)
            }
        } else {
            bluetoothTransport?.sendGattEnd()
            transitionToTerminalStateAndTeardown(terminalState: terminalState)
        }
    }
    
    /// Transitions to the final terminal state and destroys the session.
    private func transitionToTerminalStateAndTeardown(terminalState: VerifierSessionState) {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: terminalState)
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
    
    // MARK: - Inactivity Timeout
    
    // Starts the timer which tracks inactivity of any inbound or outbound event/message
    private func startInactivityTimer() {
        if inactivityTimer == nil {
            inactivityTimer = InactivityTimer { [weak self] in
                self?.handleInactivityTimeout()
            }
        }
        inactivityTimer?.start()
    }

    // Tears-down the session and returns user back to a reset state
    func handleInactivityTimeout() {
            guard let session,
                  session.currentState == .connecting || session.currentState == .verifying
            else { return }
        
        OSLoggingService.shared.logEvent(LoggingEvents.inactivityTimerGattEndFromVerifier)
        transitionToCancel()
        tearDownSession(andNotify: true)
    }
}

// MARK: - BluetoothTransportDelegate
extension VerifierOrchestrator: @MainActor BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        OSLoggingService.shared.logEvent(LoggingEvents.centralManagerPoweredOn)
    }

    public func bluetoothTransportDidStartAdvertising() {
        // Not used by Verifier
    }

    public func bluetoothTransportConnectionDidConnect() {
        if session?.currentState != .processingEngagement {
            startInactivityTimer()
            OSLoggingService.shared.logEvent(LoggingEvents.timerStartedForVerifier)
        }
        generateSessionEstablishment()
    }

    public func bluetoothTransportDidDiscover() {
        OSLoggingService.shared.logEvent(LoggingEvents.peripheralConnectionInitiated)
    }
    
    public func bluetoothTransportDidStartSession() {
        sendSessionEstablishment()
    }

    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        guard let session else { return }
        
        // resets the timer if any new bluetooth data/packets arrive
        inactivityTimer?.reset()
        
        switch session.currentState.kind {
        case .connecting:
            handleMessageInConnecting(messageData)
        case .verifying, .terminatingSession, .success, .failed, .cancelled:
            // Data arriving during or after validation is ignored
            OSLoggingService.shared.logEvent(LoggingEvents.ignoringInboundBLEData,
                                             parameters: ["currentState": session.currentState.kind.rawValue])
        default:
            didReceive(messageData)
        }
    }

    public func bluetoothTransportDidReceiveMessageEndRequest() {
        OSLoggingService.shared.logEvent(LoggingEvents.bleSessionTerminatedGattEnd)
        handleConnectionLoss(.transportError)
    }

    public func bluetoothTransportDidFinishSending() {
        inactivityTimer?.reset()
        let completion = sendCompletion
        sendCompletion = nil
        completion?()
    }

    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        switch error {
        case .central(.connectionTerminated), .central(.notPoweredOn):
            handleConnectionLoss(.transportError)
        default:
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
}
// swiftlint:enable file_length
