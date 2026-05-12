import CoreBluetooth
import Foundation
import SharingBluetoothTransport
import SharingCryptoService
import SharingPrerequisiteGate
import SwiftCBOR

public protocol HolderOrchestratorProtocol {
    var delegate: HolderOrchestratorDelegate? { get set }
    func startPresentation()
    func cancelPresentation()
    func resolve(_ missingPrerequisite: MissingPrerequisite)
}

public protocol HolderOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: HolderSessionState?)
}

// swiftlint:disable type_body_length
@MainActor
public class HolderOrchestrator: @MainActor HolderOrchestratorProtocol {
    private(set) var session: HolderSessionProtocol?
    public weak var delegate: HolderOrchestratorDelegate?
    
    // We must maintain a strong reference to PrerequisiteGate to enable the CoreBluetooth OS prompt to be displayed
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    private(set) var cryptoService: CryptoServiceProtocol?
    private(set) var bluetoothTransport: BluetoothTransportProtocol?
    private(set) var credentialRequestHandler: CredentialRequestHandlerProtocol
    
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
        
        guard let session = session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return
        }
        
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
    
    private func connectionDidConnect() {
        guard let session = session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return
        }
        
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
        guard let session = session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return
        }
        do {
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
                in: session,
                deviceResponseStatus: deviceResponseStatus
            )
        } catch {
            handleTermination(
                with: error
            )
        }
    }

    private func validateCredential(for deviceRequest: DeviceRequest, in session: HolderSessionProtocol) async {
        do {
            try await credentialRequestHandler.requestAndValidateCredential(for: deviceRequest, in: session)
            try session.transition(to: .awaitingUserConsent(deviceRequest))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch let error as CredentialRequestError {
            handleNoMatchTermination(with: error, in: session)
        } catch {
            handleTermination(with: error)
        }
    }

    private func handleNoMatchTermination(
        with error: CredentialRequestError,
        in session: HolderSessionProtocol
    ) {
        do {
            let emptyResponse = DeviceResponse(documents: nil, status: .ok)
            let encryptedData = try cryptoService?.encryptDeviceResponse(
                emptyResponse,
                in: session
            )
            let sessionData = SessionData(data: encryptedData, status: .sessionTermination)
            encodeAndSend(sessionData, with: error)
        } catch {
            handleTermination(with: error)
        }
    }
    
    func assembleAndEncryptResponse(for document: Document, in session: HolderSessionProtocol) {
        do {
            let deviceResponse = DeviceResponse(documents: [document], status: .ok)
            let encryptedData = try cryptoService?.encryptDeviceResponse(deviceResponse, in: session)
            
            if let encryptedData {
                let sessionData = SessionData(data: encryptedData)
                encodeAndSend(sessionData)
            }
        } catch {
            handleTermination(with: error)
        }
    }
    
    private func encodeAndSend(_ sessionData: SessionData, with error: Error? = nil) {
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        bluetoothTransport?.sendSessionData(encodedBytes)
        
        if let error {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }

    private func handleTermination(
        with error: Error
    ) {
        let sessionData = SessionData(status: .sessionTermination)
        encodeAndSend(sessionData, with: error)
    }

    private func handleTermination(
        with error: Error,
        in session: HolderSessionProtocol,
        deviceResponseStatus: DeviceResponseStatus
    ) {
        let errorResponse = DeviceResponse(documents: nil, status: deviceResponseStatus)
        let encryptedData = try? cryptoService?.encryptDeviceResponse(errorResponse, in: session)
        let sessionData = SessionData(data: encryptedData, status: .sessionTermination)
        encodeAndSend(sessionData, with: error)
    }

    func constructDeviceAuthenticationBytesAndGenerateDeviceSigned() async -> DeviceSigned? {
        guard let session = session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return nil
        }
        
        do {
            // Step 1: Construct the DeviceAuthenticationBytes (the data to be signed)
            let deviceAuthenticationBytes = try cryptoService?.constructDeviceAuthenticationBytes(in: session)
            guard let deviceAuthenticationBytes else {
                handleTermination(with: CryptoServiceError.deviceAuthenticationElementsNotFound)
                return nil
            }
            
            // Step 2: Retrieve the matched credential ID for signing
            guard let matchedCredential = session.matchedCredential else {
                handleTermination(with: CredentialRequestError.matchedCredentialNotFound)
                return nil
            }
            
            // Step 3: Delegate signing to the host app via CredentialProvider
            let signatureBytes = try await credentialRequestHandler.sign(
                payload: deviceAuthenticationBytes,
                documentID: matchedCredential.id
            )
            
            // Step 4: Wrap signature in COSE_Sign1 and construct DeviceSigned
            return cryptoService?.generateDeviceSigned(signatureBytes: signatureBytes, in: session)
        } catch {
            handleTermination(with: error)
            return nil
        }
    }
    
    public func cancelPresentation() {
        do {
            try session?.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        session = nil
        bluetoothTransport = nil
        cryptoService = nil
        prerequisiteGate = nil
        print("Holder Presentation Session ended")
    }
    
    public func resolve(_ missingPrerequisite: MissingPrerequisite) {
        prerequisiteGate?.triggerResolution(for: missingPrerequisite)
    }
}
// swiftlint:enable type_body_length

// MARK: - BluetoothTransport Delegate
extension HolderOrchestrator: @MainActor BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        // This delegate function is not used by the HolderOrchestrator
    }
    
    public func bluetoothTransportDidFail(with error: PeripheralError) {
        delegate?.orchestrator(didUpdateState: .failed(.generic(error.errorDescription ?? "Unknown error")))
    }
    
    public func bluetoothTransportDidStartAdvertising() {
        presentQRCode()
    }
    
    public func bluetoothTransportConnectionDidConnect() {
        connectionDidConnect()
    }
    
    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        didReceive(messageData)
    }
    
    public func bluetoothTransportDidReceiveMessageEndRequest() {
        print("BLE session terminated successfully via GATT End command")
        cancelPresentation()
    }
}
