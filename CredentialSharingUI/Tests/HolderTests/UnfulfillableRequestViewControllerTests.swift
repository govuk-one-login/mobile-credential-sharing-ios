import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("UnfulfillableRequestViewController Tests")
struct UnfulfillableRequestViewControllerTests {
    let sut = UnfulfillableRequestViewController()

    @Test("View loads with correct label")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        _ = sut.view

        // Then
        let label = try #require(sut.view.subviews.first {
            $0.accessibilityIdentifier == "UnfulfillableRequestLabel"
        } as? UILabel)

        #expect(label.text == "Unfulfillable request")
        #expect(label.textAlignment == .center)
    }

    @Test("Back button is hidden")
    func navigationBackButtonHidden() {
        // Given
        _ = sut.view

        // Then
        #expect(sut.navigationItem.hidesBackButton == true)
    }

    @Test("Background colour is system background")
    func backgroundColourIsSystemBackground() {
        // Given
        _ = sut.view

        // Then
        #expect(sut.view.backgroundColor == .systemBackground)
    }
}
