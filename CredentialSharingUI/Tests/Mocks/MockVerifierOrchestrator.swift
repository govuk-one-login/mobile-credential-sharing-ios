import SharingCryptoService
import SharingOrchestration
import SharingPrerequisiteGate

class MockVerifierOrchestrator: VerifierOrchestratorProtocol {
    weak var delegate: (any VerifierOrchestratorDelegate)?
    var startVerificationCalled = false
    var startVerificationAttributeGroup: AttributeGroup?
    var cancelVerificationCalled = false
    var confirmCancelCalled = false
    var resolveCalled = false
    var qrCodeScannedValue: String?

    /// When true, cancelVerification() will call delegate?.orchestratorDidRequestCancelConfirmation()
    var shouldRequestCancelConfirmation = false

    func startVerification(attributeGroup: AttributeGroup) {
        startVerificationCalled = true
        startVerificationAttributeGroup = attributeGroup
    }

    func cancelVerification() {
        cancelVerificationCalled = true
        if shouldRequestCancelConfirmation {
            delegate?.orchestratorDidRequestCancelConfirmation()
        }
    }

    func userDidConfirmCancel() {
        confirmCancelCalled = true
    }

    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
    }

    func qrCodeScanned(_ qrCode: String) {
        qrCodeScannedValue = qrCode
    }
}
