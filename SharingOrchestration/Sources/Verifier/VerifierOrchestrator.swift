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
    public weak var delegate: VerifierOrchestratorDelegate?
    private(set) var session: VerifierSessionProtocol?
    
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    private(set) var cryptoService: CryptoServiceProtocol?
    private(set) var bluetoothTransport: BluetoothTransportProtocol?

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
            if error as? EncryptionError == .encryptionFailed {
                print("Encryption error due to malformed SKReader key")
            }

            try? session.transition(to: .failed(.generic(error.localizedDescription)))
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            tearDownSession()
        }
    }
    
    private func generateSessionEstablishment() {
        guard let session = getSession() else { return }
        
        do {
            let deviceRequest = try constructDeviceRequest(in: session)
            try cryptoService?.generateSessionEstablishment(
                with: deviceRequest,
                in: session
            )
            
            try bluetoothTransport?.startTransport()
        } catch {
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
            try bluetoothTransport?.startScanning(in: session)
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
                
            try cryptoService?.processResponse(messageData, in: session)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
            tearDownSession()
        }
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
        // Not used by Verifier yet
    }

    public func bluetoothTransportDidFinishSending() {
        // Not used by Verifier yet
    }

    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
    }
}
