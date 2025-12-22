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
    func tapOnButtonTriggersNavigation() throws {
        // Arrange
        let sut = HolderViewController()
        let mockPresenter = MockCredentialPresenter()
        sut.credentialPresenter = mockPresenter

        // Act: Trigger viewDidLoad and access the button using the identifier
        _ = sut.view

        let presentButton = try #require(
            sut.view.subviews.first { $0.accessibilityIdentifier == HolderViewController.presentButtonIdentifier }
                as? UIButton
        )

        // Act: Simulate the button tap
        presentButton.sendActions(for: .touchUpInside)

        // Assertion: Check the state change on the mock object
        #expect(
            mockPresenter.presentCredentialCalled == true,
            "The mock presenter's presentCredential method should have been called"
        )
    }

    //    @Test("Tapping button successfully initiates navigation via the presenter")
    //    func tapOnButtonLoadsQRCodeViewController() throws {
    //        // Arrange
    //        let sut = HolderViewController()
    //        let mockPresenter = MockCredentialPresenter()
    //        sut.credentialPresenter = mockPresenter  // Inject the mock
    //
    //        // Wrap in a Nav Controller so `presentCredential` works in the test environment
    //        let navigationController = UINavigationController(
    //            rootViewController: sut
    //        )
    //
    //        // Act: Access view to trigger lifecycle
    //        _ = sut.view
    //
    //        // Use XCTestExpectation to allow the async dispatch queue call to complete within the test runner
    //        let expectation = XCTestExpectation(
    //            description: "Wait for presentation async dispatch"
    //        )
    //
    //        // Use the internal Obj-C action hook instead of calling the private function directly
    //        let presentButton = try #require(
    //            sut.view.subviews.compactMap { $0 as? UIButton }.first
    //        )
    //
    //        // Act: Simulate the button tap. This triggers the async dispatch.
    //        presentButton.sendActions(for: .touchUpInside)
    //
    //        // The async block contains the logic we want to verify
    //        // The expectation is fulfilled within the navigateToQRCodeView function after the presentation logic finishes
    //        sut.navigateToQRCodeView = {  // Override the internal navigate function to fulfill the expectation
    //            sut.credentialPresenter?.presentCredential(Data(), over: sut)
    //            sut.activityIndicator.stopAnimating()
    //            expectation.fulfill()
    //        }
    //
    //        // Wait for the expectation to be fulfilled
    //        await fulfillment(of: [expectation], timeout: 1.0)
    //
    //        // Assertions
    //        #expect(
    //            mockPresenter.presentCredentialCalled == true,
    //            "The mock presenter should have been called"
    //        )
    //        #expect(
    //            sut.activityIndicator.isAnimating == false,
    //            "Activity indicator should stop animating after navigation"
    //        )
    //        #expect(
    //            mockPresenter.presentedViewController === sut,
    //            "The correct view controller was passed to the presenter"
    //        )
    //    }

    //    @Test("Tapping button sucessfully loads QRCodeViewController")
    //    func tapOnButtonLoadsQRCodeViewController() {
    //        let sut = HolderViewController()
    //        let _ = UINavigationController(
    //            rootViewController: sut
    //        )
    //
    //        sut.navigateToQRCodeView()
    //        #expect(sut.view.subviews.count == 3)
    //    }
}
