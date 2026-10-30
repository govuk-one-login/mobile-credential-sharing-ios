#if DEBUG
import SharingCryptoService
import SharingOrchestration
import SharingPrerequisiteGate

public class MockVerifierOrchestrator: VerifierOrchestratorProtocol {
    public weak var delegate: (any VerifierOrchestratorDelegate)?
    public var startVerificationCalled = false
    public var startVerificationConfig: VerifierConfig?
    public var cancelVerificationCalled = false
    public var confirmCancelCalled = false
    public var resolveCalled = false
    public var qrCodeScannedValue: String?

    /// When true, cancelVerification() will call delegate?.orchestratorDidRequestCancelConfirmation()
    public var shouldRequestCancelConfirmation = false

    public init() {}

    public func startVerification(config: VerifierConfig) {
        startVerificationCalled = true
        startVerificationConfig = config
    }

    public func cancelVerification() {
        cancelVerificationCalled = true
        if shouldRequestCancelConfirmation {
            delegate?.orchestratorDidRequestCancelConfirmation()
        }
    }

    public func userDidConfirmCancel() {
        confirmCancelCalled = true
    }

    public func resolve(_ missingPrerequisite: MissingPrerequisite) {
        resolveCalled = true
    }

    public func qrCodeScanned(_ qrCode: String) {
        qrCodeScannedValue = qrCode
    }
}
#endif
