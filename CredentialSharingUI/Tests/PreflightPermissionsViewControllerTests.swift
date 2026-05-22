import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("PreflightPermissionViewController Tests")
struct PreflightPermissionViewControllerTests {
    var mockOrchestrator = MockHolderOrchestrator()
    var missingPrerequisites: [MissingPrerequisite] = [MissingPrerequisite.bluetooth(.authorizationNotDetermined)]
    var sut: PreflightPermissionViewController {
        PreflightPermissionViewController(missingPrerequisites, onResolve: mockOrchestrator.resolve)
    }
    
    @Test("Checking the view loads successfully with single prerequisite")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        let sut = sut
        _ = sut.view

        let stackView = try #require(sut.view.subviews.first as? UIStackView)
        let labels = stackView.arrangedSubviews.compactMap { $0 as? UILabel }
        let buttons = stackView.arrangedSubviews.compactMap { $0 as? UIButton }
        
        // Then
        #expect(labels.count == 1)
        #expect(buttons.count == 1)
        #expect(labels.first?.text == "This app needs to access your \(missingPrerequisites.first!.description).")
        #expect(buttons.first?.title(for: .normal) == "Enable \(missingPrerequisites.first!.description) prerequisite")
    }
    
    @Test("View displays both missing prerequisites when camera and bluetooth are missing")
    func displaysMultiplePrerequisites() throws {
        // Given
        let prerequisites: [MissingPrerequisite] = [
            .camera(.authorizationNotDetermined),
            .bluetooth(.authorizationNotDetermined)
        ]
        let sut = PreflightPermissionViewController(prerequisites, onResolve: mockOrchestrator.resolve)
        _ = sut.view
        
        let stackView = try #require(sut.view.subviews.first as? UIStackView)
        let labels = stackView.arrangedSubviews.compactMap { $0 as? UILabel }
        let buttons = stackView.arrangedSubviews.compactMap { $0 as? UIButton }
        
        // Then
        #expect(labels.count == 2)
        #expect(buttons.count == 2)
        #expect(labels[0].text == "This app needs to access your \(prerequisites[0].description).")
        #expect(labels[1].text == "This app needs to access your \(prerequisites[1].description).")
    }

    @Test("Button triggers orchestrator resolve function")
    func buttonTriggersResolve() throws {
        // Given
        var resolved: MissingPrerequisite?
        let sut = PreflightPermissionViewController(
            [.bluetooth(.authorizationNotDetermined)]
        ) { resolved = $0 }
        _ = sut.view
        let stackView = try #require(sut.view.subviews.first as? UIStackView)
        let button = try #require(
            stackView.arrangedSubviews.compactMap { $0 as? UIButton
            }.first)
        
        // When
        button.sendActions(for: .touchUpInside)
        
        // Then
        #expect(resolved == .bluetooth(.authorizationNotDetermined))
    }
    
    @Test("Correct prerequisite is resolved per button")
    func correctPrerequisiteResolved() throws {
        var resolved: MissingPrerequisite?
        let prerequisites: [MissingPrerequisite] = [
            .camera(.authorizationNotDetermined),
            .bluetooth(.authorizationNotDetermined)
        ]
        let sut = PreflightPermissionViewController(prerequisites) {
            resolved = $0
        }
        _ = sut.view
        let stackView = try #require(sut.view.subviews.first as? UIStackView)
        let buttons = stackView.arrangedSubviews.compactMap { $0 as? UIButton }
        
        // When
        buttons[1].sendActions(for: .touchUpInside)
        
        // Then
        #expect(resolved == .bluetooth(.authorizationNotDetermined))
    }
}
