import CoreBluetooth
import Foundation
import SharingBluetoothTransport
import SharingCryptoService
import SharingPrerequisiteGate
import SwiftCBOR

// swiftlint:disable file_length
@MainActor
// swiftlint:disable:next type_body_length
public class ISOHolderOrchestrator: HolderOrchestratorProtocol {
    private(set) var session: ISOHolderSessionProtocol?
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
    
    public func start() {
        session = ISOHolderSession()
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
                try session?.transition(to: .isoReadyToPresent)
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
            try session?.transition(to: .isoPresentingEngagement(qrCode: qrCode))
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    // MARK: - Transport & Data
    private func connectionDidConnect() {
        guard let session = getSession() else { return }
        
        do {
            // TODO: DCMAW-18497 Look into changing the behaviour of connectionDidConnect within BLEPeripheralTransport .handleDidSubscribe() to avoid this check
            if session.currentState != .isoProcessingEstablishment {
                try session.transition(to: .isoProcessingEstablishment)
                delegate?.orchestrator(didUpdateState: session.currentState)
            }
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func didReceive(_ messageData: Data) {
        guard let session = getSession() else { return }
        do {
            // Guard to prevent deviceRequest error being thrown beyond processingEstablishment
            guard session.currentState == .isoProcessingEstablishment else {
                return
            }
            let deviceRequest = try cryptoService?.processSessionEstablishment(incoming: messageData, in: session)
            if let deviceRequest {
                Task {
                    await self.validateCredential(for: deviceRequest, in: session)
                }
            }
        } catch let error as DeviceRequestError {
            let deviceResponseStatus: DeviceResponseStatus = error == .dataIsNotValidCBOR ?
                .cborDecodingError :
                .cborValidationError
            
            handleTermination(
                with: error,
                deviceResponseStatus: deviceResponseStatus
            )
        } catch {
            handleTermination(
                with: error
            )
        }
    }

    private func validateCredential(for deviceRequest: DeviceRequest, in session: ISOHolderSessionProtocol) async {
        do {
            try await credentialRequestHandler.requestAndValidateCredential(for: deviceRequest, in: session)
            
            filterIssuerSigned(for: deviceRequest, in: session)
        } catch let error as CredentialRequestError {
            handleTermination(with: error, deviceResponseStatus: .ok)
        } catch {
            handleTermination(with: error)
        }
    }
    
    private func filterIssuerSigned(for deviceRequest: DeviceRequest, in session: ISOHolderSessionProtocol) {
        do {
            try credentialRequestHandler.filterIssuerSigned(for: deviceRequest, in: session)
            
            try session.transition(to: .awaitingUserConsent(deviceRequest))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch let error as IssuerSignedFilterError {
            print(error.localizedDescription)
            var statusCode: DeviceResponseStatus?
            switch error {
            case .noMatchingNameSpaces, .noMatchingAttributes:
                statusCode = .ok
            case .exceededAgeOverLimit:
                statusCode = .generalError
            }
            handleTermination(with: error, deviceResponseStatus: statusCode ?? .generalError)
        } catch {
            handleTermination(with: error)
        }
    }
    
    public func userDidApprove() {
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
            try cryptoService?.constructDeviceAuthenticationBytes(in: session)
            try await credentialRequestHandler.signDeviceAuthenticationBytes(in: session)
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
            
            if let encryptedData {
                let sessionData = SessionData(data: encryptedData)
                encodeAndSend(sessionData) {
                    /// Callback to trigger transition to `.success` state when response sent successfully
                    self.transitionToSuccess()
                }
            }
        } catch {
            handleTermination(with: error)
        }
    }
    
    private func transitionToSuccess() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .success)
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

    // MARK: - Interruption & Cancellation
    private func handleTermination(
        with error: Error?
    ) {
        let sessionData = SessionData(status: .sessionTermination)
        encodeAndSend(sessionData, with: error)
        
        print("SessionData sent: \(sessionData)")
    }

    private func handleTermination(
        with error: Error?,
        deviceResponseStatus: DeviceResponseStatus
    ) {
        guard let session = getSession() else { return }
        do {
            let errorResponse = DeviceResponse(documents: nil, status: deviceResponseStatus)
            let encryptedData = try cryptoService?.encryptDeviceResponse(errorResponse, in: session)
            let sessionData = SessionData(data: encryptedData, status: .sessionTermination)
            encodeAndSend(sessionData, with: error)
        } catch {
            handleTermination(with: error)
        }
    }
    
    public func userDidDeny() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .processingResponse)
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            handleTermination(
                with: nil,
                deviceResponseStatus: .ok
            )
            
            transitionToCancel()
            tearDownSession(andNotify: false)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    public func cancel() {
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
    
    private func getSession() -> ISOHolderSessionProtocol? {
        guard let session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return nil
        }
        return session
    }
}

// MARK: - BluetoothTransport Delegate
extension ISOHolderOrchestrator: @MainActor BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        // This delegate function is not used by the ISOHolderOrchestrator
    }
    
    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        delegate?.orchestrator(didUpdateState: .failed(.generic(error.errorDescription ?? "Unknown error")))
    }
    
    public func bluetoothTransportDidStartAdvertising() {
        presentQRCode()
    }
    
    public func bluetoothTransportConnectionDidConnect() {
        connectionDidConnect()
    }

    public func bluetoothTransportDidDiscover() {
        // This delegate function is not used by the ISOHolderOrchestrator
    }
    
    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        didReceive(messageData)
    }
    
    public func bluetoothTransportDidReceiveMessageEndRequest() {
        print("BLE session terminated successfully via GATT End command")
        if session?.currentState != .success {
            transitionToCancel()
        }
        tearDownSession(andNotify: false)
    }
    
    public func bluetoothTransportDidFinishSending() {
        let completion = sendCompletion
        sendCompletion = nil
        completion?()
    }
}
// swiftlint:enable file_length
