import CredentialSharingUI
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
        
        // Act: Trigger viewDidLoad and access the button using the identifier
        UIWindow().rootViewController = sut
        _ = sut.view

        // Assert using accessibility identifiers
        let presentButton = sut.view.subviews.first {
            $0.accessibilityIdentifier == HolderViewController.presentButtonIdentifier
        }
        let foundButton = try #require(presentButton as? UIButton)

        // Act: Simulate the button tap
        foundButton.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 50 * 1_000_000)
        
        // Assertion: Check the HolderContainerNavigation is presented
        #expect(sut.presentedViewController != nil)
    }
}
