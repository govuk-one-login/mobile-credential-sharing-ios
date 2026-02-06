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
        var permissionsToRequest = PrerequisiteGate.checkCapabilities(for: [.bluetooth])
        do {
            try session?.transition(
                to: .preflight(missingPermissions: permissionsToRequest)
            )
            
            // TODO: Request permissions on UI
//            delegate.requestPermissions(for: permissionsToRequest)
            // Temporary request before UI impl
            requestPermission(for: .bluetooth)
            
            // At this point we must wait for the TemporaryPeripheralManagerDelegate.peripheralManagerDidUpdateState() function to detect that the permissions have been updated
            
            
            // TODO: Once we've determined the permissions have been accpeted from the delegate method, we can checkCapabilities again and resume the journey.
            permissionsToRequest = PrerequisiteGate.checkCapabilities(for: [.bluetooth])
            
            guard permissionsToRequest.isEmpty else {
                // throw error
                return
            }
            try session?.transition(to: .readyToPresent)
            print(session?.currentState)
        } catch {
            
        }
    }
    
    public func cancelPresentation() {
        session = nil
        print("Holder Presentation Session ended")
    }
    
    // TODO: To be called from UI layer
    public func requestPermission(for capability: Capability) {
        prerequisiteGate = PrerequisiteGate()
        prerequisiteGate?.requestPermission(for: capability)
    }
}
