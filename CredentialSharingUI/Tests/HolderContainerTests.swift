import CryptoService
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
    
    @Test("didTapCancel triggers orchestrator cancelPresentation func")
    func didTapCancelTriggersOrchestrator() {
        // Given
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        
        // When
        sut.didTapCancel()
        
        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
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
                .contains(where: { $0 is PreflightPermissionViewController })
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
                .contains(where: { $0 is ErrorViewController })
        )
        
        let errorViewController = try #require(navigationController.viewControllers
            .first(where: { $0 is ErrorViewController }))
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
                .contains(where: { $0 is ErrorViewController })
        )
        
        let errorViewController = try #require(navigationController.viewControllers
            .first(where: { $0 is ErrorViewController }))
        _ = try #require(errorViewController.view.subviews.first {
            ($0 as? UILabel)?.text == "Something went wrong. Try again later."
        })
    }
    
    @Test("render(for: .presenting) with Bluetooth permission .notDetermined triggers PreflightPermissionViewController")
    func renderTriggersQRCodeView() async throws {
        // Given
        let sut = HolderContainer()
        let qrCode = try QRGenerator(data: Data()).generateQRCode()
        let state = HolderSessionState.presentingEngagement(qrCode: qrCode)
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
                .contains(where: { $0 is QRCodeViewController })
        )
    }
    
    // MARK: - HolderContainerNavigation Tests
    @Test("Sets presentationController delegate to self")
    func viewWillLoadSetsDelegate() {
        // Given
        let sut = HolderContainerNavigation()
        #expect(sut.presentationController?.delegate == nil)
        
        // When
        sut.viewWillAppear(false)
        
        // Then
        #expect(sut.presentationController?.delegate === sut.self)
    }
    
    @Test("presentationControllerDidDismiss calls HolderContainer.didTapCancel()")
    func presentationControllerDismissCallsCancel() throws {
        // Given
        let sut = HolderContainerNavigation(holderContainer: HolderContainer(orchestrator: mockOrchestrator))
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        
        // When
        sut.presentationControllerDidDismiss(try #require(sut.presentationController))
        
        // Then
        #expect(mockOrchestrator.cancelPresentationCalled == true)
    }
    
    @Test("render(for: .cancelled) dismisses navigationController")
    func renderDismissesNavigation() async throws {
        // Given
        let sut = HolderContainer()
        let state = HolderSessionState.cancelled
        let baseMockNavigationController = MockNavigationController(
            rootViewController: sut
        )
        _ = sut.view
        _ = baseMockNavigationController.view
        
        // When
        sut.render(for: state)
        
        // Then
        let navigationController = try #require(sut.navigationController)
        #expect(navigationController === baseMockNavigationController)
        #expect(navigationController.viewControllers.count == 1)
        print(baseMockNavigationController.viewControllers)
        #expect(baseMockNavigationController.dismissCalled)
    }
}

class EmptyViewController: UIViewController {}

class MockNavigationController: UINavigationController {
    var dismissCalled = false
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCalled = true
    }
}
