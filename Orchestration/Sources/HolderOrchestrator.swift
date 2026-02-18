import BluetoothTransport
import CoreBluetooth
import Foundation
import PrerequisiteGate

public protocol HolderOrchestratorProtocol {
    var delegate: HolderOrchestratorDelegate? { get set }
    func startPresentation()
    func cancelPresentation()
    func requestPermission(for capability: Capability)
}

public protocol HolderOrchestratorDelegate: AnyObject {
    func render(for state: HolderSessionState?)
}

public class HolderOrchestrator: HolderOrchestratorProtocol {
    private(set) var session: HolderSession?
    public weak var delegate: HolderOrchestratorDelegate?
    
    // We must maintain a strong reference to PrerequisiteGate to enable the CoreBluetooth OS prompt to be displayed
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    
    public init() {
        // Empty init required to declare class as public facing
    }
    
    init(prerequisiteGate: PrerequisiteGateProtocol? = nil) {
        self.prerequisiteGate = prerequisiteGate
    }
      
    public func startPresentation() {
        session = HolderSession()
        print("Holder Presentation Session started")
        
        // MARK: - PrerequisiteGate
        performPreflightChecks()
    }

    func performPreflightChecks() {
        if prerequisiteGate == nil {
            prerequisiteGate = PrerequisiteGate()
            prerequisiteGate?.delegate = self
        }
        guard let prerequisiteGate = prerequisiteGate else {
            delegate?.render(for: .error("PrerequisiteGate is not available."))
            return
        }
        do {
            let permissionsToRequest = prerequisiteGate.checkCapabilities(
                for: [.bluetooth()]
            )
            if permissionsToRequest.isEmpty {
                try session?.transition(to: .readyToPresent)
                print(session?.currentState ?? "")
                // doNextFunc()
                                
            } else {
                if permissionsToRequest.contains(where: { $0 == .bluetooth(.bluetoothStateUnknown) }) {
                    // If the bluetooth state is unknown, it means the CBPeripheralManager
                    // has not had a chance to fully initiate so we return & wait for the
                    // PeripheralManagerDelegate to report a state change & re-run the preflight checks
                    return
                } else {
                    try session?.transition(
                        to: .preflight(missingPermissions: permissionsToRequest)
                    )
                    
                    // Request permissions on UI
                    for permission in permissionsToRequest {
                        switch permission {
                        case .bluetooth(.bluetoothAuthDenied), .bluetooth(.bluetoothAuthRestricted):
                            delegate?.render(for: .error(permission.rawValue))
                        default:
                            delegate?.render(for: session?.currentState)
                        }
                    }
                }
            }
        } catch {
            delegate?.render(for: .error(error.localizedDescription))
        }
        
    }
    
    public func cancelPresentation() {
        session = nil
        print("Holder Presentation Session ended")
    }
    
    public func requestPermission(for capability: Capability) {
        prerequisiteGate?.requestPermission(for: capability)
    }
}

// MARK: - PrerequisiteGate Delegate
extension HolderOrchestrator: PrerequisiteGateDelegate {
    public func bluetoothTransportDidUpdateState(withError error: BluetoothTransport.PeripheralError?) {
        performPreflightChecks()
    }
}
