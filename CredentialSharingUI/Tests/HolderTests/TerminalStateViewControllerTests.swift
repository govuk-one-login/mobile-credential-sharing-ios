import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("TerminalStateViewController Tests")
struct TerminalStateViewControllerTests {

    @Test("View loads with provided message")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        let sut = TerminalStateViewController(message: "Details shared")
        _ = sut.view

        // Then
        let label = try #require(sut.view.subviews.first {
            $0.accessibilityIdentifier == "TerminalStateLabel"
        } as? UILabel)

        #expect(label.text == "Details shared")
        #expect(label.textAlignment == .center)
    }

    @Test("View displays different message")
    func displaysConfiguredMessage() throws {
        // Given
        let sut = TerminalStateViewController(message: "Unfulfillable request")
        _ = sut.view

        // Then
        let label = try #require(sut.view.subviews.first {
            $0.accessibilityIdentifier == "TerminalStateLabel"
        } as? UILabel)

        #expect(label.text == "Unfulfillable request")
    }

    @Test("Back button is hidden")
    func navigationBackButtonHidden() {
        // Given
        let sut = TerminalStateViewController(message: "Test")
        _ = sut.view

        // Then
        #expect(sut.navigationItem.hidesBackButton == true)
    }

    @Test("Background colour is system background")
    func backgroundColourIsSystemBackground() {
        // Given
        let sut = TerminalStateViewController(message: "Test")
        _ = sut.view

        // Then
        #expect(sut.view.backgroundColor == .systemBackground)
    }
}
