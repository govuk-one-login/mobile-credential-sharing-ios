import Foundation

public protocol HolderOrchestratorProtocol {
    func startPresentation()
    func cancelPresentation()
}

public class HolderOrchestrator: HolderOrchestratorProtocol {
    private(set) var session: HolderSession?
    
    public init() {
        // Empty init required to declare class as public facing
    }
      
    public func startPresentation() {
        session = HolderSession()
        print("Holder Presentation Session started")
    }
    
    public func cancelPresentation() {
        session = nil
        print("Holder Presentation Session ended")
    }
}

// TODO: DCMAW-18156 - HolderSession implementation to come
public struct HolderSession: Equatable {
    
}
