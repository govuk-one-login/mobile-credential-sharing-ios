import Orchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
struct HolderContainerTests {

    let baseViewController = EmptyViewController()
    let mockOrchestrator = MockHolderOrchestrator()
    var sut: HolderContainer {
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
    
    @Test("render(for: .preflight) with Bluetooth permission .notDetermined triggers PreflightPermissionViewController")
    func renderTriggersPreflightView() async throws {
        // Given
        let sut = HolderContainer()
        let state = HolderSessionState.preflight(
            missingPermissions: [.bluetooth()]
        )
        let baseNavigationController = UINavigationController(
            rootViewController: sut
        )
        _ = sut.view
        _ = baseNavigationController.view
        
        // When
        sut.render(for: state)
        
        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController === baseNavigationController)
        #expect(navigationController.viewControllers.count == 2)
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == PreflightPermissionViewController.self) })
        )
    }
    
    @Test("render(for: .error) triggers ErrorViewController")
    func renderPermissionsDeniedTriggersErrorView() async throws {
        // Given
        let sut = HolderContainer()
        let state = HolderSessionState.error("Mock error description")
        let baseNavigationController = UINavigationController(
            rootViewController: sut
        )
        _ = sut.view
        _ = baseNavigationController.view
        
        // When
        sut.render(for: state)
        
        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController === baseNavigationController)
        #expect(navigationController.viewControllers.count == 2)
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        
        let errorViewController = try #require(navigationController.viewControllers
            .first(where: { (type(of: $0) == ErrorViewController.self) }))
        _ = try #require(errorViewController.view.subviews.first {
            ($0 as? UILabel)?.text == "Mock error description"
        })
    }
    
    @Test("render() with no state passed triggers ErrorViewController")
    func renderNoStateTriggersErrorView() async throws {
        // Given
        let sut = HolderContainer()
        let baseNavigationController = UINavigationController(
            rootViewController: sut
        )
        _ = sut.view
        _ = baseNavigationController.view
        
        // When
        sut.render(for: nil)
        
        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController === baseNavigationController)
        #expect(navigationController.viewControllers.count == 2)
        #expect(
            navigationController.viewControllers
                .contains(where: { (type(of: $0) == ErrorViewController.self) })
        )
        
        let errorViewController = try #require(navigationController.viewControllers
            .first(where: { (type(of: $0) == ErrorViewController.self) }))
        _ = try #require(errorViewController.view.subviews.first {
            ($0 as? UILabel)?.text == "Something went wrong. Try again later."
        })
    }
}
