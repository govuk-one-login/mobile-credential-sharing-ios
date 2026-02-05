import HolderUI
import Testing
internal import UIKit

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("HolderViewControllerTests")
struct HolderViewControllerTests {

    @Test("All necessary subviews are present and configured")
    func checkViewSetupCorrectly() throws {
        // Arrange
        let sut = HolderViewController()

        // Act: Accessing the view triggers viewDidLoad() and setupView()
        _ = sut.view

        // Assert using accessibility identifiers
        let presentButton = sut.view.subviews.first {
            $0.accessibilityIdentifier == HolderViewController.presentButtonIdentifier
        }
        let activityIndicator = sut.view.subviews.first {
            $0.accessibilityIdentifier == HolderViewController.activityIndicatorIdentifier
        }

        let foundButton = try #require(presentButton as? UIButton)
        let foundIndicator = try #require(activityIndicator as? UIActivityIndicatorView)

        #expect(foundButton.title(for: .normal) == "Present Credential")
        #expect(sut.title == "Holder")
        #expect(foundIndicator.hidesWhenStopped == true)
        #expect(foundIndicator.isAnimating == false)
    }

    @Test("Tapping button successfully triggers the navigation hook")
    func tapOnButtonTriggersNavigation() async throws {
        // Arrange
        let sut = HolderViewController()
        // TODO: DCMAW-18155 Fully replace MockCredentialPresenter with MockHolderOrchaestrator when refactor complete
        let mockPresenter = MockCredentialPresenter()
        let mockOrchestrator = MockHolderOrchestrator()
        sut.credentialPresenter = mockPresenter
        sut.orchestrator = mockOrchestrator
        
        _ = UINavigationController(
            rootViewController: sut
        )
        
        // Act: Trigger viewDidLoad and access the button using the identifier
        _ = sut.view

        // Assert using accessibility identifiers
        let presentButton = sut.view.subviews.first {
            $0.accessibilityIdentifier == HolderViewController.presentButtonIdentifier
        }
        let foundButton = try #require(presentButton as? UIButton)

        // Act: Simulate the button tap
        foundButton.sendActions(for: .touchUpInside)

        try await Task.sleep(nanoseconds: 50 * 1_000_000)
        
        // Assertion: Check the state change on the mock object
        #expect(
            mockPresenter.presentCredentialCalled == true,
            "The mock presenter's presentCredential method should have been called"
        )
        #expect(
            mockOrchestrator.startPresentationCalled == true,
            "The mock orchestrator's startPresentation method should have been called"
        )
    }
}
