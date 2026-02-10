import CoreBluetooth
import Foundation
import PrerequisiteGate

public protocol HolderOrchestratorProtocol {
    func startPresentation()
    func cancelPresentation()
}

public class HolderOrchestrator: HolderOrchestratorProtocol {
    private(set) var session: HolderSession?
    
    // We must maintain a strong reference to PrerequisiteGate to enable the CoreBluetooth OS prompt to be displayed
    private(set) var prerequisiteGate: PrerequisiteGate?
    
    public init() {
        // Empty init required to declare class as public facing
    }
      
    public func startPresentation() {
        session = HolderSession()
        print("Holder Presentation Session started")
        
        // MARK: - PrerequisiteGate
        performPreflightChecks()
            
        // At this point we must wait for the TemporaryPeripheralManagerDelegate.peripheralManagerDidUpdateState() function to detect that the permissions have been updated
    }

    func performPreflightChecks() {
        let permissionsToRequest = PrerequisiteGate.checkCapabilities(
            for: [.bluetooth]
        )
        do {
            // TODO: Check if empty and transition to ready to present
            try session?.transition(
                to: .preflight(missingPermissions: permissionsToRequest)
            )
            
            // TODO: DCMAW-18471 Request permissions on UI
            // delegate.render(for: session.currentState)
            
            // TODO: DCMAW-18471 Temporary request before UI impl (to be called from UI layer)
            requestPermission(for: .bluetooth)
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
        prerequisiteGate = PrerequisiteGate()
        prerequisiteGate?.delegate = self
        prerequisiteGate?.requestPermission(for: capability)
    }
}

// MARK: - PrerequisiteGate Delegate
extension HolderOrchestrator: PrerequisiteGateDelegate {
    public func didUpdatePermissions() {
        let permissionsToRequest = PrerequisiteGate.checkCapabilities(
            for: [.bluetooth]
        )

        if permissionsToRequest.isEmpty {
            do {
                try session?.transition(to: .readyToPresent)
                print(session?.currentState ?? "")
                // doNextFunc()
            } catch {
                // TODO: DCMAW-18471 Render error screen if BLE permission is denied
                // delegate.render(for: error)
            }
        } else {
            
            performPreflightChecks()
        }
    }
}
