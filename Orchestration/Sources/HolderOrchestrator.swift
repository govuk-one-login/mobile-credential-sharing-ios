import Foundation
import CoreBluetooth
import PrerequisiteGate

public protocol HolderOrchestratorProtocol {
    func startPresentation()
    func cancelPresentation()
}

public class HolderOrchestrator: HolderOrchestratorProtocol, PrerequisiteGateDelegate {
    private(set) var session: HolderSession?
    var waiting: Bool = false
    
    // We must maintain a strong reference to PrerequisiteGate to enable the CoreBluetooth OS prompt to be displayed
    private(set) var prerequisiteGate: PrerequisiteGate?
    
    public init() {
        // Empty init required to declare class as public facing
    }
      
    public func startPresentation() {
        session = HolderSession()
        print("Holder Presentation Session started")
        
        // MARK: - PrerequisiteGate
        beginPrerequisiteFlow()
            
            
        // At this point we must wait for the TemporaryPeripheralManagerDelegate.peripheralManagerDidUpdateState() function to detect that the permissions have been updated
            
            
        // TODO: Once we've determined the permissions have been accpeted from the delegate method, we can checkCapabilities again and resume the journey.
        
     
    }

    func beginPrerequisiteFlow() {
        var permissionsToRequest = PrerequisiteGate.checkCapabilities(
            for: [.bluetooth]
        )
        do {
            try session?.transition(
                to: .preflight(missingPermissions: permissionsToRequest)
            )
            
            // TODO: Request permissions on UI
            //            delegate.render(for: session.currentState)
            
            // Temporary request before UI impl
            requestPermission(for: .bluetooth)
        } catch {
        }
    }

    
    public func didUpdatePermissions() {
        let permissionsToRequest = PrerequisiteGate.checkCapabilities(
            for: [.bluetooth]
        )

        if permissionsToRequest.isEmpty {
            do {
                try session?.transition(to: .readyToPresent)
                print(session?.currentState)
            } catch  {
                
            }
            // doNextFunc()
        } else {
            guard CBManager.authorization != .denied else {
//            TODO: Render error screen if BLE permission is denied
//                delegate.render(for: session.currentState)
                print("Permissions denied, show UI to request permissions")
                return
            }
            beginPrerequisiteFlow()
        }
        
    }
    
    public func cancelPresentation() {
        session = nil
        print("Holder Presentation Session ended")
    }
    
    // TODO: To be called from UI layer
    public func requestPermission(for capability: Capability) {
        prerequisiteGate = PrerequisiteGate()
        prerequisiteGate?.delegate = self
        prerequisiteGate?.requestPermission(for: capability)
    }
}

