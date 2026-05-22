import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ProcessingEstablishmentViewController Tests")
struct ProcessingEstablishmentViewControllerTests {
    let sut = ProcessingEstablishmentViewController()
    
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        let activityIndicator = sut.view.subviews.first {
            $0.accessibilityIdentifier == ProcessingEstablishmentViewController.activityIndicatorIdentifier
        }
        // When
        _ = sut.view
        
        // Then
        #expect(sut.view.subviews.count == 1)
        #expect(
            sut.title == "Processing establishment..."
        )
        _ = try #require(activityIndicator as? UIActivityIndicatorView)
        #expect(activityIndicator?.isHidden == false)
    }
}
