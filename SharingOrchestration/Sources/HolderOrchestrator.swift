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

public class HolderOrchestrator: HolderOrchestratorProtocol {
    private(set) var session: HolderSessionProtocol?
    public weak var delegate: HolderOrchestratorDelegate?
    
    // We must maintain a strong reference to PrerequisiteGate to enable the CoreBluetooth OS prompt to be displayed
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    private(set) var cryptoService: CryptoServiceProtocol?
    private(set) var bluetoothTransport: BluetoothTransportProtocol?
    
    public init() {
        // Empty init required to declare class as public facing
    }
    
    init(prerequisiteGate: PrerequisiteGateProtocol? = nil,
         bluetoothTransport: BluetoothTransportProtocol? = nil,
         cryptoService: CryptoServiceProtocol? = nil) {
        self.prerequisiteGate = prerequisiteGate
        self.bluetoothTransport = bluetoothTransport
        self.cryptoService = cryptoService
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
                try session.transition(to: .requestReceived(deviceRequest))
                delegate?.orchestrator(didUpdateState: session.currentState)
            }
        } catch let error as DeviceRequestError {
            handleTermination(
                with: error,
                in: session,
                deviceResponseStatus: .cborDecodingError
            )
        } catch {
            handleTermination(
                with: error
            )
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

// MARK: - BluetoothTransport Delegate
extension HolderOrchestrator: BluetoothTransportDelegate {
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
