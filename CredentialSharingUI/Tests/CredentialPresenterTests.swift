@testable import CredentialSharingUI
import GDSLogging
import SharingOrchestration
import Testing
import UIKit
import X509

@Suite("CredentialPresenter Tests")
struct CredentialPresenterTests {

    // MARK: - New trusted-certificate interface

    @Test("Initializes with trusted reader certificates and provider")
    @MainActor
    func initializesWithTrustedCertificates() throws {
        let provider = MockCredentialProvider()
        let presenter = try CredentialPresenter(
            trustedReaderCertificates: [try MockReaderAuthRootCertificate.root],
            credentialProvider: provider,
            completion: {}
        )
        
        _ = presenter
    }

    @Test("Analytics service is accepted when provided")
    @MainActor
    func analyticsServiceIsAccepted() throws {
        let provider = MockCredentialProvider()
        let analytics = MockAnalyticsService()
        let presenter = try CredentialPresenter(
            trustedReaderCertificates: [try MockReaderAuthRootCertificate.root],
            credentialProvider: provider,
            analyticsService: analytics,
            completion: {}
        )

        _ = presenter
    }

    @Test("Returns navigation controller for sharing journey")
    @MainActor
    func returnsNavigationController() throws {
        let provider = MockCredentialProvider()
        let presenter = try CredentialPresenter(
            trustedReaderCertificates: [try MockReaderAuthRootCertificate.root],
            credentialProvider: provider,
            completion: {}
        )

        let viewController = presenter.viewControllerForSharingJourney()

        #expect(viewController is HolderContainerNavigation)
    }

    @Test("Navigation controller contains HolderContainer as root")
    @MainActor
    func navigationContainsHolderContainer() throws {
        let provider = MockCredentialProvider()
        let presenter = try CredentialPresenter(
            trustedReaderCertificates: [try MockReaderAuthRootCertificate.root],
            credentialProvider: provider,
            completion: {}
        )

        let viewController = presenter.viewControllerForSharingJourney()
        let navController = viewController as? HolderContainerNavigation

        #expect(navController?.viewControllers.first is HolderContainer)
    }

    // MARK: - Empty-list rejection

    @Test("Empty trusted certificate list is rejected")
    @MainActor
    func emptyTrustedCertificatesRejected() {
        let provider = MockCredentialProvider()

        #expect(throws: CredentialPresenterConfigurationError.missingTrustedReaderCertificates) {
            _ = try CredentialPresenter(
                trustedReaderCertificates: [],
                credentialProvider: provider,
                completion: {}
            )
        }
    }

    // MARK: - Deprecated interface compatibility

    @Test("Deprecated initializer remains available")
    @MainActor
    @available(*, deprecated, message: "Exercises the deprecated initializer on purpose")
    func deprecatedInitializerRemainsAvailable() {
        let provider = MockCredentialProvider()

        let presenter = CredentialPresenter(
            credentialProvider: provider,
            logger: MockAnalyticsService(),
            completion: {}
        )

        #expect(presenter.viewControllerForSharingJourney() is HolderContainerNavigation)
    }
}

// MARK: - Mock Credential Provider
private class MockCredentialProvider: CredentialProvider {
    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        return [Credential(id: "test-id", rawCredential: Data())]
    }

    func sign(payload: Data, documentID: String) async throws(CredentialSigningError) -> Data {
        return Data()
    }
}
