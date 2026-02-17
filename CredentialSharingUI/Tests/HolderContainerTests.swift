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
            orchestrator: mockOrchestrator
        )
    }
    
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        _ = sut.view

        let activityIndicator = sut.view.subviews.first {
            $0.accessibilityIdentifier == HolderContainer.activityIndicatorIdentifier
        }
        
        // When
        sut.viewDidLoad()
        
        // Then
        _ = try #require(activityIndicator as? UIActivityIndicatorView)
        #expect(sut.view.subviews.count == 1)
    }
    
    @Test("startPresentation triggers orchestrator startPResentation func")
    func startPresentationTriggersOrchestrator() {
        // Given
        #expect(mockOrchestrator.startPresentationCalled == false)
        
        // When
        sut.viewWillAppear(false)
        
        // Then
        #expect(mockOrchestrator.startPresentationCalled == true)
    }
//    
//    @Test("render(for: .preflight) triggers PreflightPermissionViewController")
//    func renderTriggersCorrectView() async throws {
//        // Given
//        let state = HolderSessionState.preflight(missingPermissions: [.bluetooth()])
//        
//        // When
//        sut.render(for: state)
//        
//        // Then
//        #expect(type(of: sut.navController?.presentedViewController) == PreflightPermissionViewController.self)
//    }
}
