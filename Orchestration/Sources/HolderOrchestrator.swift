import BluetoothTransport
import Foundation
import PrerequisiteGate

public protocol HolderOrchestratorProtocol {
    func startPresentation()
    func cancelPresentation()
}

public class HolderOrchestrator: HolderOrchestratorProtocol {
    private(set) var session: HolderSession?
    
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
            
        // At this point we must wait for the TemporaryPeripheralManagerDelegate.peripheralManagerDidUpdateState() function to detect that the permissions have been updated
    }

    func performPreflightChecks() {
        if prerequisiteGate == nil {
            prerequisiteGate = PrerequisiteGate()
        }
        guard let prerequisiteGate = prerequisiteGate else {
            fatalError("preRequisiteGate can never be nil here")
//            delegate?.render("GenericError")
        }
        do {
            let permissionsToRequest = prerequisiteGate.checkCapabilities(
                for: [.bluetooth]
            )
            try session?.transition(
                to: .preflight(missingPermissions: permissionsToRequest)
            )
            if permissionsToRequest.isEmpty {
                try session?.transition(to: .readyToPresent)
                print(session?.currentState ?? "")
                // doNextFunc()
                                
            } else {
                try session?.transition(
                    to: .preflight(missingPermissions: permissionsToRequest)
                )
                
                // TODO: DCMAW-18471 Request permissions on UI
                // delegate.render(for: session.currentState)
                
                // TODO: DCMAW-18471 Temporary request before UI impl (to be called from UI layer)
                requestPermission(for: .bluetooth)
            }
        } catch {
            // TODO: DCMAW-18471 Render error screen if BLE permission is denied
            // delegate.render(for: error)
        }
    }
    
    public func cancelPresentation() {
        session = nil
        print("Holder Presentation Session ended")
    }
    
    // TODO: DCMAW-18471 To be called from UI layer
    public func requestPermission(for capability: Capability) {
        prerequisiteGate?.delegate = self
        prerequisiteGate?.requestPermission(for: capability)
    }
}

// MARK: - PrerequisiteGate Delegate
extension HolderOrchestrator: PrerequisiteGateDelegate {
    public func bluetoothTransportDidUpdateState(withError error: BluetoothTransport.PeripheralError?) {
        switch error {
        case nil:
            performPreflightChecks()
        default:
            break
//            delegate?.render(BLE_ERROR(error.description))
        }
    }
}
