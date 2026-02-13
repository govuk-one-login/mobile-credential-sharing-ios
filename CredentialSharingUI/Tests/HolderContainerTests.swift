import Orchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
struct HolderContainerTests {

    let baseViewController = EmptyViewController()
    let mockOrchestrator = MockHolderOrchestrator()
    var sut: HolderContainer {
        _ = UINavigationController(rootViewController: baseViewController)
        return HolderContainer(
            over: baseViewController,
            orchestrator: mockOrchestrator
        )
    }
    
    @Test("startPresentation triggers orchestrator startPResentation func")
    func startPresentationTriggersOrchestrator() {
        // Given
        #expect(mockOrchestrator.startPresentationCalled == false)
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(mockOrchestrator.startPresentationCalled == true)
    }
    
    @Test(".render(for: .preflight) navigates to PreflightPermissionViewController")
    func renderNavigatesToPreflightPermissionView() throws {
        // Given
        let navController = try #require(sut.navController)
        #expect(navController.viewControllers.count == 1)
        
        // When
        
        // Then
        #expect(
            navController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        
    }
}
