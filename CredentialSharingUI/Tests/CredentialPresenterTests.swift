@testable import CredentialSharingUI
import Logging
import Testing
import UIKit

@Suite("CredentialPresenter Tests")
struct CredentialPresenterTests {
    
    @Test("Initializes with credential provider")
    @MainActor
    func initializesWithProvider() {
        let provider = MockCredentialProvider()
        let presenter = CredentialPresenter(
            credentialProvider: provider,
            completion: {}
        )
        
        // Presenter is successfully created
        _ = presenter
    }
    
    @Test("Returns navigation controller for sharing journey")
    @MainActor
    func returnsNavigationController() {
        let provider = MockCredentialProvider()
        let presenter = CredentialPresenter(
            credentialProvider: provider,
            completion: {}
        )
        
        let viewController = presenter.viewControllerForSharingJourney()
        
        #expect(viewController is HolderContainerNavigation)
    }
    
    @Test("Navigation controller contains HolderContainer as root")
    @MainActor
    func navigationContainsHolderContainer() {
        let provider = MockCredentialProvider()
        let presenter = CredentialPresenter(
            credentialProvider: provider,
            completion: {}
        )
        
        let viewController = presenter.viewControllerForSharingJourney()
        let navController = viewController as? HolderContainerNavigation
        
        #expect(navController?.viewControllers.first is HolderContainer)
    }
    
    @Test("Logger is accepted when provided")
    @MainActor
    func loggerIsAccepted() {
        let provider = MockCredentialProvider()
        let logger = MockAnalyticsService()
        let presenter = CredentialPresenter(
            credentialProvider: provider,
            logger: logger,
            completion: {}
        )
        
        // Logger would be called during actual usage
        _ = presenter
    }
}

// MARK: - Mock Credential Provider
private class MockCredentialProvider: CredentialProvider {
    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        return [Credential(id: "test-id", rawCredential: Data())]
    }
    
    func sign(payload: Data, documentID: String) async throws -> Data {
        return Data()
    }
}
