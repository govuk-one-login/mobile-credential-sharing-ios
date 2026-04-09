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
    func requestPermission(for missingPrerequisite: MissingPrerequisite)
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
            prerequisiteGate?.delegate = self
        }
        guard let prerequisiteGate = prerequisiteGate else {
//            delegate?.orchestrator(didUpdateState: .error("PrerequisiteGate is not available."))
            return
        }
        do {
            let missingPrerequisites = prerequisiteGate.evaluatePrerequisites(
                for: [.bluetooth]
            )
            if missingPrerequisites.isEmpty {
                try session?.transition(to: .readyToPresent)
                print(session?.currentState ?? "")
                
                // MARK: - Initialisation & Device Engagement
                prepareEngagement()
                
            } else {
                if missingPrerequisites.contains(where: {
                    if case .bluetooth(.stateUnknown) = $0 {
                        return true
                    }
                    return false
                }) {
                    // If the bluetooth state is unknown, it means the CBPeripheralManager
                    // has not had a chance to fully initiate so we return & wait for the
                    // PeripheralManagerDelegate to report a state change & re-run the preflight checks
                    return
                } else {
                    // Request permissions on UI
                    if let unrecoverablePrerequisite = missingPrerequisites.first(where: { !$0.isRecoverable }) {
                        try session?.transition(
                            to: .failed(.unrecoverablePrerequisite(unrecoverablePrerequisite))
                        )
                        delegate?
                            .orchestrator(didUpdateState: session?.currentState)
                        return
                    }
                    try session?.transition(
                        to: .preflight(missingPermissions: missingPrerequisites)
                    )
                    delegate?
                        .orchestrator(didUpdateState: session?.currentState)
                }
            }
        } catch {
            //            delegate?.orchestrator(didUpdateState: .error(error.localizedDescription))
        }
        
    }
    
    func prepareEngagement() {
        let sessionDecryption = SessionDecryption()
        if cryptoService == nil {
            cryptoService = CryptoService(sessionDecryption: sessionDecryption)
        }
        
        guard let session = session else {
//            delegate?.orchestrator(didUpdateState: .error("Session is not available."))
            return
        }
        
        do {
            try cryptoService?.prepareEngagement(in: session)
            guard session.cryptoContext != nil,
                  session.qrCode != nil,
                  session.serviceUUID != nil else {
//                delegate?.orchestrator(
//                    didUpdateState: .error("Session engagement failed to prepare correctly.")
//                )
                return
            }
                        
            if bluetoothTransport == nil {
                bluetoothTransport = BluetoothTransport()
                bluetoothTransport?.delegate = self
            }
           
            try bluetoothTransport?.startAdvertising(in: session)
            // Once .startAdvertising has been called, we must wait for the delegate function to detect that it was successful, call presentQRCode & transition to the new state
        } catch {
//            delegate?.orchestrator(didUpdateState: .error(error.localizedDescription))
        }
    }
    
    private func presentQRCode() {
        guard let qrCode = session?.qrCode else {
//            delegate?.orchestrator(didUpdateState: .error("QR Code failed to generate."))
            return
        }
        
        do {
            try session?.transition(to: .presentingEngagement(qrCode: qrCode))
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
//            delegate?.orchestrator(didUpdateState: .error(error.localizedDescription))
        }
    }
    
    private func connectionDidConnect() {
        guard let session = session else {
//            delegate?.orchestrator(didUpdateState: .error("Session is not available."))
            return
        }
        
        do {
            // TODO: DCMAW-18497 Look into changing the behaviour of connectionDidConnect within BLEPeripheralTransport .handleDidSubscribe() to avoid this check
            if session.currentState != .processingEstablishment {
                try session.transition(to: .processingEstablishment)
                delegate?.orchestrator(didUpdateState: session.currentState)
            }
        } catch {
//            delegate?.orchestrator(didUpdateState: .error(error.localizedDescription))
        }
    }
    
    private func didReceive(_ messageData: Data) {
        guard let session = session else {
//            delegate?.orchestrator(didUpdateState: .error("Session is not available."))
            return
        }
        do {
            let deviceRequest = try cryptoService?.processSessionEstablishment(incoming: messageData, in: session)
            if let deviceRequest {
                try session.transition(to: .requestReceived(deviceRequest))
                delegate?.orchestrator(didUpdateState: session.currentState)
            }
        } catch {
            let terminationMessage = SessionData(status: 20)
            let encodedBytes = Data(terminationMessage.encode(options: CBOROptions()))
            bluetoothTransport?.sendSessionData(encodedBytes)
//            delegate?.orchestrator(didUpdateState: .error(error.localizedDescription))
        }
    }
    
    public func cancelPresentation() {
        do {
            try session?.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
//            delegate?.orchestrator(didUpdateState: .error(error.localizedDescription))
        }
        session = nil
        bluetoothTransport = nil
        cryptoService = nil
        prerequisiteGate = nil
        print("Holder Presentation Session ended")
    }
    
    public func requestPermission(for missingPrerequisite: MissingPrerequisite) {
        prerequisiteGate?.requestPermission(for: missingPrerequisite)
    }
}

// MARK: - PrerequisiteGate Delegate
extension HolderOrchestrator: PrerequisiteGateDelegate {
    public func prerequisiteGateBluetoothDidReportChange() {
        performPreflightChecks()
    }
}

// MARK: - BluetoothTransport Delegate
extension HolderOrchestrator: BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        // This delegate function is not used by the HolderOrchestrator
    }
    
    public func bluetoothTransportDidFail(with error: PeripheralError) {
//        delegate?.orchestrator(didUpdateState: .error(error.errorDescription ?? "Unknown error"))
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
