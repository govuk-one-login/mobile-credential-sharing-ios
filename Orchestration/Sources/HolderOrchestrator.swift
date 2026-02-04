import Foundation

public class HolderOrchestrator {
    private var session: HolderSession?
    
    public init() {
        // Empty init required to declare class as public facing
    }
      
    public func startPresentation(with credential: Data) {
        session = HolderSession()
        print("Holder Presentation Session started")
    }
    
    public func cancelPresentation() {
        session = nil
        print("Holder Presentation Session ended")
    }
}

// TODO: DCMAW-18156 - HolderSession implementation to come
struct HolderSession {
    
}
