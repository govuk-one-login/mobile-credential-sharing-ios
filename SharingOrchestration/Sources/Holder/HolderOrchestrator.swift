import CoreBluetooth
import Foundation
import SharingBluetoothTransport
import SharingCryptoService
import SharingPrerequisiteGate
import SwiftCBOR

// swiftlint:disable file_length
@MainActor
public protocol HolderOrchestratorProtocol {
    var delegate: HolderOrchestratorDelegate? { get set }
    func startPresentation()
    func userDidTapCancel()
    func resolve(_ missingPrerequisite: MissingPrerequisite)
    func userDidTapApprove()
    func userDidTapDeny()
}

public protocol HolderOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: HolderSessionState?)
}

@MainActor
// swiftlint:disable:next type_body_length
public class HolderOrchestrator: @MainActor HolderOrchestratorProtocol {
    /// Buffer between send-completion and GATT End to allow the peer time to receive and process the preceding SessionData.
    private static let gattEndDelay: Int = 500
    
    private(set) var session: HolderSessionProtocol?
    public weak var delegate: HolderOrchestratorDelegate?
    
    // We must maintain a strong reference to PrerequisiteGate to enable the CoreBluetooth OS prompt to be displayed
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    private(set) var cryptoService: CryptoServiceProtocol?
    private(set) var bluetoothTransport: BluetoothTransportProtocol?
    private(set) var credentialRequestHandler: CredentialRequestHandlerProtocol
    private var sendCompletion: (() -> Void)?
    
    
    public init(credentialRequestHandler: CredentialRequestHandlerProtocol) {
        self.credentialRequestHandler = credentialRequestHandler
    }
    
    init(prerequisiteGate: PrerequisiteGateProtocol? = nil,
         bluetoothTransport: BluetoothTransportProtocol? = nil,
         cryptoService: CryptoServiceProtocol? = nil,
         credentialRequestHandler: CredentialRequestHandlerProtocol) {
        self.prerequisiteGate = prerequisiteGate
        self.bluetoothTransport = bluetoothTransport
        self.cryptoService = cryptoService
        self.credentialRequestHandler = credentialRequestHandler
        self.bluetoothTransport?.delegate = self
    }
    
    public func startPresentation() {
        session = HolderSession()
        print("Holder Presentation Session started")
        
        // MARK: - Pre-flight Checks
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
                for: [.bluetooth]
            ) {
                self.performPreflightChecks()
            }
            if missingPrerequisites.isEmpty {
                try session?.transition(to: .readyToPresent)
                print(session?.currentState ?? "")
                
                // MARK: - Initialisation & Device Engagement
                prepareEngagement()
                
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
                    delegate?
                        .orchestrator(didUpdateState: session?.currentState)
                    return
                }
                try session?.transition(
                    to: .preflight(missingPrerequisites: missingPrerequisites)
                )
                delegate?
                    .orchestrator(didUpdateState: session?.currentState)
            }
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        
    }
    
    func prepareEngagement() {
        let sessionDecryption = SessionDecryption()
        if cryptoService == nil {
            cryptoService = CryptoService(sessionDecryption: sessionDecryption)
        }
        
        guard let session = getSession() else { return }
        
        do {
            try cryptoService?.prepareEngagement(in: session)
            guard session.cryptoContext != nil,
                  session.qrCode != nil,
                  session.serviceUUID != nil else {
                delegate?.orchestrator(
                    didUpdateState: .failed(.generic("Session engagement failed to prepare correctly."))
                )
                return
            }
                        
            if bluetoothTransport == nil {
                bluetoothTransport = BluetoothTransport()
                bluetoothTransport?.delegate = self
            }
           
            try bluetoothTransport?.startAdvertising(in: session)
            // Once .startAdvertising has been called, we must wait for the delegate function to detect that it was successful, call presentQRCode & transition to the new state
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func presentQRCode() {
        guard let qrCode = session?.qrCode else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("QR Code failed to generate.")))
            return
        }
        
        do {
            try session?.transition(to: .presentingEngagement(qrCode: qrCode))
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    // MARK: - Transport & Data
    private func didFailTransport(with error: BluetoothTransportError) {
        guard let session,
              session.currentState.isActiveState else {
            return
        }
        
        try? session.transition(to: .failed(.generic(error.errorDescription ?? "Unknown error")))
        delegate?.orchestrator(didUpdateState: session.currentState)
        tearDownSession(andNotify: false)
    }
    
    private func connectionDidConnect() {
        guard let session = getSession() else { return }
        
        do {
            // TODO: DCMAW-18497 Look into changing the behaviour of connectionDidConnect within BLEPeripheralTransport .handleDidSubscribe() to avoid this check
            if session.currentState != .processingEstablishment {
                try session.transition(to: .processingEstablishment)
                delegate?.orchestrator(didUpdateState: session.currentState)
            }
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func didReceive(_ messageData: Data) {
        guard let session = getSession() else { return }
        do {
            // Sequencing violation in awaitingUserConsent or processingResponse
            guard session.currentState == .processingEstablishment else {
                // Ignore messages if already terminating or in terminal state
                guard session.currentState.kind != .terminatingSession,
                      session.currentState.kind != .success,
                      session.currentState.kind != .failed,
                      session.currentState.kind != .cancelled else { return }
                
                // Status-only SessionData triggers peer termination handling
                if let sessionData = try? SessionData(fromCBOR: messageData), sessionData.data == nil {
                    handlePeerTermination(sessionData: sessionData)
                    return
                }
                initiateTermination(then: .failed(.sequencingViolation))
                return
            }
            
            let deviceRequest = try cryptoService?.processSessionEstablishment(incoming: messageData, in: session)
            
            if let deviceRequest {
                Task {
                    await self.validateCredential(for: deviceRequest, in: session)
                }
            }
        } catch CryptoServiceError.sessionDataReceived(let sessionData) {
            if sessionData.data == nil {
                // Status-only SessionData: peer termination signal
                handlePeerTermination(sessionData: sessionData)
            } else {
                // SessionData with data when SessionEstablishment expected: sequencing violation
                initiateTermination(then: .failed(.sequencingViolation))
            }
        } catch let error as SessionEstablishmentError {
            // SessionEstablishment CBOR decode failure
            initiateTermination(then: .failed(.generic(error.errorDescription ?? "Unknown error")))
        } catch is DecryptionError {
            // SessionEstablishment decryption failure
            initiateTermination(then: .failed(.generic("Decryption failed")))
        } catch let error as CryptoServiceError {
            // Crypto key agreement or context failure during SessionEstablishment processing
            initiateTermination(then: .failed(.generic(error.errorDescription ?? "Unknown error")))
        } catch let error as DeviceRequestError {
            // DeviceRequest CBOR decode failure or validation failure
            let deviceResponseStatus: DeviceResponseStatus =
            error == .dataIsNotValidCBOR ?
                .cborDecodingError :
                .cborValidationError
            
            initiateTermination(
                deviceResponseStatus: deviceResponseStatus,
                then: .failed(.invalidDeviceRequest)
            )
        } catch {
            initiateTermination(
                then: .failed(.generic(error.localizedDescription))
            )
        }
    }

    private func validateCredential(for deviceRequest: DeviceRequest, in session: HolderSessionProtocol) async {
        do {
            try await credentialRequestHandler.requestAndValidateCredential(for: deviceRequest, in: session)
            
            filterIssuerSigned(for: deviceRequest, in: session)
        } catch let error as CredentialRequestError {
            handleTermination(with: error, deviceResponseStatus: .ok)
        } catch {
            handleTermination(with: error)
        }
    }
    
    private func filterIssuerSigned(for deviceRequest: DeviceRequest, in session: HolderSessionProtocol) {
        do {
            try credentialRequestHandler.filterIssuerSigned(for: deviceRequest, in: session)
            
            try session.transition(to: .awaitingUserConsent(deviceRequest))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch let error as IssuerSignedFilterError {
            print(error.localizedDescription)
            switch error {
            case .noMatchingNameSpaces, .noMatchingAttributes:
                initiateTermination(deviceResponseStatus: .ok, then: .success(reason: .emptyResponse))
            case .exceededAgeOverLimit:
                initiateTermination(deviceResponseStatus: .generalError, then: .failed(.invalidDeviceRequest))
            case .portraitNotRequested:
                initiateTermination(deviceResponseStatus: .generalError, then: .failed(.policyViolation))
            }
        } catch {
            handleTermination(with: error)
        }
    }
    
    public func userDidTapApprove() {
        guard let session = getSession() else { return }
        
        do {
            try session.transition(to: .processingResponse)
            delegate?.orchestrator(didUpdateState: session.currentState)
            Task {
                await prepareDeviceSignedResponse()
                print("prepDevSignedResponse returned")
            }
        } catch {
            handleTermination(with: error)
        }
    }
    
    func prepareDeviceSignedResponse() async {
        guard let session = getSession() else { return }

        do {
            try cryptoService?.constructSigStructure(in: session)
            try await credentialRequestHandler.signSigStructure(in: session)
            try cryptoService?.generateDeviceSigned(in: session)
            
            assembleAndEncryptResponse()
        } catch {
            handleTermination(with: error)
        }
    }
    
    func assembleAndEncryptResponse() {
        guard let session = getSession() else { return }
        guard let docType = session.docType,
        let issuerSigned = session.issuerSigned,
        let deviceSigned = session.deviceSigned else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return
        }
        let document = Document(
            docType: docType,
            issuerSigned: issuerSigned,
            deviceSigned: deviceSigned
        )
        do {
            let deviceResponse = DeviceResponse(documents: [document], status: .ok)
            let encryptedData = try cryptoService?.encryptDeviceResponse(deviceResponse, in: session)
            try session.setDeviceResponse(deviceResponse)
            
            if let encryptedData {
                let sessionData = SessionData(data: encryptedData)
                encodeAndSend(sessionData) {
                    /// Callback to trigger transition to `.awaitingVerifierResolution` state when response sent successfully
                    self.transitionToAwaitingVerifierResolution()
                }
            }
        } catch {
            handleTermination(with: error)
        }
    }
    
    private func transitionToAwaitingVerifierResolution() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .awaitingVerifierResolution)
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            try? session.transition(to: .failed(.incorrectSessionState(session.currentState.kind.rawValue)))
            delegate?.orchestrator(didUpdateState: session.currentState)
        }
    }
    
    private func transitionToTerminalState(_ terminalState: HolderSessionState) {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: terminalState)
            delegate?.orchestrator(didUpdateState: session.currentState)

        } catch {
            try? session.transition(to: .failed(.incorrectSessionState(session.currentState.kind.rawValue)))
            delegate?.orchestrator(didUpdateState: session.currentState)
        }
    }

    private func encodeAndSend(_ sessionData: SessionData, with error: Error? = nil, completion: (() -> Void)? = nil) {
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        sendCompletion = completion
        bluetoothTransport?.sendSessionData(encodedBytes)
        
        if let error {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }

    // MARK: - Peer Termination (Inbound SessionData with status, no data)
    
    /// Handles an incoming status-only SessionData from the Verifier indicating session termination.
    /// No outbound signal (no GATT End, no termination message) is sent.
    /// - In `awaitingVerifierResolution`: status 20 == success, non-20 == failed (screen stays on "details shared").
    /// - In pre-response states: any status == failed with generic error screen.
    private func handlePeerTermination(sessionData: SessionData) {
        guard let session = getSession() else { return }
        
        switch session.currentState.kind {
        case .awaitingVerifierResolution:
            if sessionData.status == .sessionTermination {
                transitionToTerminalState(.success(reason: .responseSent))
            } else {
                transitionToTerminalState(.failed(.peerTermination))
            }
            tearDownSession(andNotify: false)
            
        case .processingEstablishment, .awaitingUserConsent, .processingResponse:
            transitionToTerminalState(.failed(.peerTermination))
            tearDownSession(andNotify: false)
            
        default:
            break
        }
    }
    
    // MARK: - Initiating Termination (Ordered Teardown)
    
    /// Initiates programmatic termination
    /// 1. CryptoService builds SessionData(status: 20) with optional encrypted payload
    /// 2. Orchestrator sends the message via BluetoothTransport
    /// 3. Wait for send-completion + 500ms  buffer
    /// 4. Send GATT End
    /// 5. Transition to terminal state
    /// 6. Destroy session
    private func initiateTermination(
        deviceResponseStatus: DeviceResponseStatus? = nil,
        then terminalState: HolderSessionState
    ) {
        guard let session = getSession() else { return }
        do {
            
            var encryptedPayload: Data?
            if let deviceResponseStatus {
                let errorResponse = DeviceResponse(documents: nil, status: deviceResponseStatus)
                encryptedPayload = try? cryptoService?.encryptDeviceResponse(errorResponse, in: session)
                try session.setDeviceResponse(errorResponse)
            }
            
            try session.transition(to: .terminatingSession)
            sendTerminationMessage(encryptedPayload: encryptedPayload) {
                self.performDelayedGATTEndAndTeardown(then: terminalState)
            }
        } catch {
            sendTerminationMessage()
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }

    // MARK: - Interruption & Cancellation

    /// Sends a bare termination message (status: 20, no payload) and notifies delegate of failure.
    /// Used for error paths where the full delayed GATT End teardown is not required.
    private func handleTermination(with error: Error?, deviceResponseStatus: DeviceResponseStatus? = nil) {
        guard let session = getSession() else { return }
        
        var encryptedPayload: Data?
        if let deviceResponseStatus {
            let errorResponse = DeviceResponse(documents: nil, status: deviceResponseStatus)
            encryptedPayload = try? cryptoService?.encryptDeviceResponse(errorResponse, in: session)
        }
        
        sendTerminationMessage(encryptedPayload: encryptedPayload)
        
        if let error {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func sendTerminationMessage(encryptedPayload: Data? = nil, completion: (() -> Void)? = nil) {
        guard let session = getSession() else { return }
        let terminationBytes = cryptoService?.buildTerminationMessage(encryptedPayload: encryptedPayload, in: session)
        
        if let terminationBytes {
            sendCompletion = completion
            bluetoothTransport?.sendSessionData(terminationBytes)
        }
        print("Termination message sent")
    }
    
    public func userDidTapDeny() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .processingResponse)
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            initiateTermination(deviceResponseStatus: .ok, then: .success(reason: .denialResponse))
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func performDelayedGATTEndAndTeardown(then terminalState: HolderSessionState) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.gattEndDelay))
            
            self.bluetoothTransport?.sendGattEnd()
            self.transitionToTerminalState(terminalState)
            self.tearDownSession(andNotify: false)
        }
    }
    
    public func userDidTapCancel() {
        guard session != nil else { return }
        transitionToCancel()
        tearDownSession(andNotify: true)
    }
    
    private func transitionToCancel() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session.currentState)
            print("State transitioned to cancelled")
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func tearDownSession(andNotify: Bool) {
        session?.connectionHandle?.notify = andNotify
        bluetoothTransport = nil
        session = nil
        cryptoService = nil
        prerequisiteGate = nil
        print("Holder Presentation Session ended")
    }
    
    public func resolve(_ missingPrerequisite: MissingPrerequisite) {
        prerequisiteGate?.triggerResolution(for: missingPrerequisite)
    }
    
    private func getSession() -> HolderSessionProtocol? {
        guard let session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return nil
        }
        return session
    }
}

// MARK: - BluetoothTransport Delegate
extension HolderOrchestrator: @MainActor BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        // This delegate function is not used by the HolderOrchestrator
    }
    
    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        didFailTransport(with: error)
    }
    
    public func bluetoothTransportDidStartAdvertising() {
        presentQRCode()
    }
    
    public func bluetoothTransportConnectionDidConnect() {
        connectionDidConnect()
    }

    public func bluetoothTransportDidDiscover() {
        // This delegate function is not used by the HolderOrchestrator
    }
    
    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        didReceive(messageData)
    }
    
    public func bluetoothTransportDidReceiveMessageEndRequest() {
        print("BLE session terminated via GATT End command")
        
        guard let session else {
            tearDownSession(andNotify: false)
            return
        }
        
        switch session.currentState.kind {
        case .awaitingVerifierResolution:
            sendCompletion = nil
            transitionToTerminalState(.success(reason: .responseSent))
        case .processingResponse:
            sendCompletion = nil
            transitionToTerminalState(.success(reason: .denialResponse))
        case .processingEstablishment:
            sendCompletion = nil
            transitionToTerminalState(.success(reason: .emptyResponse))
        default:
            transitionToCancel()
        }
        tearDownSession(andNotify: false)
    }
    
    public func bluetoothTransportDidFinishSending() {
        let completion = sendCompletion
        sendCompletion = nil
        completion?()
    }
    
    public func bluetoothTransportDidStartSession() {
        // This delegate function is not used by the HolderOrchestrator
    }
}
// swiftlint:enable file_length
