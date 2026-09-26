import GDSLogging
import SharingOrchestration
import UIKit
import X509

/// Errors that prevent a `CredentialPresenter` from being configured.
public enum CredentialPresenterConfigurationError: Error, Equatable, Sendable {
    /// No trusted ReaderAuth root certificates were supplied.
    case missingTrustedReaderCertificates
}

/// Main entry point for the Holder role.
/// The Consumer initialises this class to start a credential sharing session.
@MainActor
public class CredentialPresenter {
    private let credentialProvider: CredentialProvider
    private let trustedReaderCertificates: [Certificate]
    private let analyticsService: AnalyticsService?
    private let completion: () -> Void
    private var orchestrator: HolderOrchestratorProtocol

    /// Initialises the Holder module with a credential provider and trusted ReaderAuth roots.
    /// - Parameters:
    ///   - trustedReaderCertificates: Non-empty set of trusted ReaderAuth root certificates.
    ///   - credentialProvider: Supplies credentials and signing capabilities.
    ///   - analyticsService: Optional analytics service for logging.
    ///   - completion: Called when the sharing session completes.
    /// - Throws: `.missingTrustedReaderCertificates` when the certificate list is empty.
    public init(
        trustedReaderCertificates: [Certificate],
        credentialProvider: CredentialProvider,
        analyticsService: AnalyticsService? = nil,
        completion: @escaping () -> Void
    ) throws(CredentialPresenterConfigurationError) {
        guard !trustedReaderCertificates.isEmpty else {
            throw .missingTrustedReaderCertificates
        }
        self.trustedReaderCertificates = trustedReaderCertificates
        self.credentialProvider = credentialProvider
        self.analyticsService = analyticsService
        self.completion = completion
        let handler = CredentialRequestHandler(credentialProvider: credentialProvider)
        self.orchestrator = HolderOrchestrator(credentialRequestHandler: handler)
    }

    /// Deprecated. Use the initialiser that supplies `trustedReaderCertificates`.
    @available(*, deprecated, message: "Supply trustedReaderCertificates")
    public init(
        credentialProvider: CredentialProvider,
        logger: AnalyticsService? = nil,
        completion: @escaping () -> Void
    ) {
        self.trustedReaderCertificates = []
        self.credentialProvider = credentialProvider
        self.analyticsService = logger
        self.completion = completion
        let handler = CredentialRequestHandler(credentialProvider: credentialProvider)
        self.orchestrator = HolderOrchestrator(credentialRequestHandler: handler)
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
