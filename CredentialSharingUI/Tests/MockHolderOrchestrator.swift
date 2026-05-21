import SharingOrchestration
import SharingPrerequisiteGate

class MockHolderOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    
    var session: HolderSession?
    var startPresentationCalled = false
    var cancelPresentationCalled = false
    var resolveCalled = false
    var userDidConsentCalled = false
    var userDeniedConsentCalled = false
    
    func startPresentation() {
        startPresentationCalled = true
    }
    
    func cancelPresentation(triggeredByUser: Bool) {
        cancelPresentationCalled = true
    }
    
    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
    }
    
    func userDidConsent() {
        userDidConsentCalled = true
    }
    
    func userDeniedConsent() {
        
    }
}
