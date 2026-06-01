import Foundation
import SharingCryptoService
import SharingPrerequisiteGate

@MainActor
public protocol VerifierOrchestratorProtocol {
    var delegate: VerifierOrchestratorDelegate? { get set }
    func startVerification()
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

    public init() {
        // Empty init required to declare class as public facing
    }

    init(
        prerequisiteGate: PrerequisiteGateProtocol? = nil,
        cryptoService: CryptoServiceProtocol? = nil
    ) {
        self.prerequisiteGate = prerequisiteGate
        self.cryptoService = cryptoService
    }

    public func startVerification() {
        let newSession = VerifierSession()
        session = newSession
        print("Verifier session started \(ObjectIdentifier(newSession))")
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
        }
    }

    public func cancelVerification() {
        do {
            try session?.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session?.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        session = nil
        prerequisiteGate = nil
        print("Verifier session ended")
    }

    public func resolve(_ missingPrerequisite: MissingPrerequisite) {
        prerequisiteGate?.triggerResolution(for: missingPrerequisite)
    }
    
    public func qrCodeScanned(_ qrCode: String) {
        guard let session = getSession() else { return }
        if isMdocString(qrCode) {
            do {
                try session.transition(to: .processingEngagement)
                delegate?.orchestrator(didUpdateState: session.currentState)
                processQRCode(qrCode)
            } catch {
                
            }
        }
    }
    
    func processQRCode(_ qrCode: String) {
        guard let session = getSession() else { return }
        
        let sessionDecryption = SessionDecryption()
        if cryptoService == nil {
            cryptoService = CryptoService(sessionDecryption: sessionDecryption)
        }
        
        do {
            try cryptoService?.processQRCode(qrCode, in: session)
            print(qrCode)
            
            try session.transition(to: .connecting)
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            try? session.transition(to: .failed(.generic(error.localizedDescription)))
            delegate?.orchestrator(didUpdateState: session.currentState)
        }
    }
    
    private func isMdocString(_ value: String) -> Bool {
        return value.lowercased().hasPrefix("mdoc:")
    }
    
    private func getSession() -> VerifierSessionProtocol? {
        guard let session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return nil
        }
        return session
    }
}
