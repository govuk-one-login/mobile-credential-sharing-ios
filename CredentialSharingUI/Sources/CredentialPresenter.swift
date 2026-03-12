import Orchestration
import UIKit

/// Main entry point for the Holder role.
/// The Consumer initialises this class to start a credential sharing session.
@MainActor
public class CredentialPresenter {
    private let credentialProvider: CredentialProvider
    private let logger: ((String) -> Void)?
    private let completion: () -> Void
    private var orchestrator: HolderOrchestratorProtocol
    
    /// Initialises the Holder module with a credential provider.
    /// - Parameters:
    ///   - credentialProvider: The provider that supplies credentials and signing capabilities
    ///   - logger: Optional logging closure
    ///   - completion: Closure called when the sharing session completes
    public init(
        credentialProvider: CredentialProvider,
        logger: ((String) -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        self.credentialProvider = credentialProvider
        self.logger = logger
        self.completion = completion
        self.orchestrator = HolderOrchestrator()
    }
    
    /// Returns a view controller that manages the sharing journey.
    /// The Consumer presents this view controller to start the Device Engagement UI (QR code).
    /// - Returns: A view controller that displays the QR code and manages the sharing flow
    public func viewControllerForSharingJourney() -> UIViewController {
        let container = HolderContainer(orchestrator: orchestrator)
        let navigationController = HolderContainerNavigation(holderContainer: container)
        return navigationController
    }
}
