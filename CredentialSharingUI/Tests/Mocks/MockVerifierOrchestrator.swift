import SharingCryptoService
import SharingOrchestration
import SharingPrerequisiteGate

class MockVerifierOrchestrator: VerifierOrchestratorProtocol {
    weak var delegate: (any VerifierOrchestratorDelegate)?
    var startVerificationCalled = false
    var startVerificationAttributeGroup: AttributeGroup?
    var cancelVerificationCalled = false
    var resolveCalled = false
    var qrCodeScannedValue: String?

    func startVerification(attributeGroup: AttributeGroup) {
        startVerificationCalled = true
        startVerificationAttributeGroup = attributeGroup
    }

    func cancelVerification() {
        cancelVerificationCalled = true
    }

    func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
    }

    func qrCodeScanned(_ qrCode: String) {
        qrCodeScannedValue = qrCode
    }
}
