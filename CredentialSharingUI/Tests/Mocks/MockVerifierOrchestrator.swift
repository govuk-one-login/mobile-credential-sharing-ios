import SharingOrchestration
import SharingPrerequisiteGate

class MockVerifierOrchestrator: VerifierOrchestratorProtocol {
    weak var delegate: (any VerifierOrchestratorDelegate)?
    var startVerificationCalled = false
    var cancelVerificationCalled = false
    var resolveCalled = false

    func startVerification() {
        startVerificationCalled = true
    }

    func cancelVerification() {
        cancelVerificationCalled = true
    }

    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
    }
    
    var qrCodeScannedValue: String?

    func qrCodeScanned(_ qrCode: String) {
        qrCodeScannedValue = qrCode
    }
}
