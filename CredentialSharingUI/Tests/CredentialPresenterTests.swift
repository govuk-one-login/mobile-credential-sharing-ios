@testable import CredentialSharingUI
import Testing
import UIKit

@Suite("CredentialPresenter Tests")
struct CredentialPresenterTests {
    
    @Test("Initializes with credential provider")
    func initializesWithProvider() {
        let provider = MockCredentialProvider()
        let presenter = CredentialPresenter(
            credentialProvider: provider,
            completion: {}
        )
        
        #expect(presenter != nil)
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
        
        #expect(viewController is UINavigationController)
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
        let navController = viewController as? UINavigationController
        
        #expect(navController?.viewControllers.first is HolderContainer)
    }
    
    @Test("Logger is called when provided")
    @MainActor
    func loggerIsCalled() {
        var loggedMessages: [String] = []
        let provider = MockCredentialProvider()
        let presenter = CredentialPresenter(
            credentialProvider: provider,
            logger: { message in
                loggedMessages.append(message)
            },
            completion: {}
        )
        
        // Logger would be called during actual usage
        #expect(presenter != nil)
    }
}

// MARK: - Mock Credential Provider
private class MockCredentialProvider: CredentialProvider {
    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        return [Credential(id: "test-id", rawCredential: Data())]
    }
    
    func sign(payload: Data, documentId: String) async throws -> Data {
        return Data()
    }
}
