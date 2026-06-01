import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ProcessingViewController Tests")
struct ProcessingViewControllerTests {
    let sut = ProcessingViewController()
    
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        let activityIndicator = sut.view.subviews.first {
            $0.accessibilityIdentifier == ProcessingViewController.activityIndicatorIdentifier
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
