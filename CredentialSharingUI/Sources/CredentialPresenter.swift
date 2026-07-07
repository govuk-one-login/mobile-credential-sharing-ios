import Logging
import SharingNetworkTransport
import SharingOrchestration
import UIKit

/// Main entry point for the Holder role.
/// The Consumer initialises this class to start a credential sharing session.
@MainActor
public class CredentialPresenter {
    private let credentialProvider: CredentialProvider
    private let logger: AnalyticsService?
    private let completion: () -> Void
    private var orchestrator: any HolderOrchestratorProtocol

    /// Initialises the Holder module with a credential provider.
    /// - Parameters:
    ///   - credentialProvider: The provider that supplies credentials and signing capabilities
    ///   - logger: Optional analytics service for logging
    ///   - completion: Closure called when the sharing session completes
    public init(
        credentialProvider: CredentialProvider,
        logger: AnalyticsService? = nil,
        completion: @escaping () -> Void
    ) {
        self.credentialProvider = credentialProvider
        self.logger = logger
        self.completion = completion
        let handler = CredentialRequestHandler(credentialProvider: credentialProvider)
        self.orchestrator = ISOHolderOrchestrator(credentialRequestHandler: handler)
    }

    /// Returns a view controller that manages the ISO sharing journey.
    /// The Consumer presents this view controller to start the Device Engagement UI (QR code).
    /// - Returns: A view controller that displays the QR code and manages the sharing flow
    public func viewControllerForISOSharingJourney() -> UIViewController {
        let container = HolderContainer(orchestrator: orchestrator)
        let navigationController = HolderContainerNavigation(holderContainer: container)
        return navigationController
    }

    /// Returns a view controller that manages the OID4VP (Remote) sharing journey initiated by a
    /// `openid4vp://` deeplink. The SDK fetches and validates the request, then shows the consent screen.
    /// - Parameter deeplink: The `openid4vp://` engagement URL received by the app.
    public func viewControllerForRemoteSharingJourney(deeplink: URL) -> UIViewController {
        let transport = SharingNetworkingClient()
        orchestrator = RemoteHolderOrchestrator(deeplink: deeplink, remoteTransport: transport)
        let container = HolderContainer(orchestrator: orchestrator)
        let navigationController = HolderContainerNavigation(holderContainer: container)
        return navigationController
    }
}
