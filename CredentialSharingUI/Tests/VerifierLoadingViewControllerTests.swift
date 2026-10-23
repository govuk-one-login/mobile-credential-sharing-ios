import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("VerifierLoadingViewController Tests")
struct VerifierLoadingViewControllerTests {
    let sut = VerifierLoadingViewController()
    
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        let activityIndicator = sut.view.subviews.first {
            $0.accessibilityIdentifier == VerifierLoadingViewController.activityIndicatorIdentifier
        }
        // When
        _ = sut.view
        
        // Then
        #expect(sut.view.subviews.count == 1)
        #expect(
            sut.title == "Processing..."
        )
        _ = try #require(activityIndicator as? UIActivityIndicatorView)
        #expect(activityIndicator?.isHidden == false)
    }
}
