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
        PreflightPermissionViewController(missingPrerequisites, mockOrchestrator)
    }
    
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() throws {
        // Given
        _ = sut.view

        let enablePermissionsButton = sut.view.subviews.first {
            $0.accessibilityIdentifier == PreflightPermissionViewController.enablePermissionsButtonIdentifier
        }
        let foundButton = try #require(enablePermissionsButton as? UIButton)
        
        // When
        sut.viewDidLoad()
        let missingPrerequisites = missingPrerequisites
        // Then
        #expect(sut.view.subviews.count == 2)
        #expect(
            sut.view.subviews.contains(where: {
                $0 is UILabel && ($0 as? UILabel)?.text == "This app needs to access your \(missingPrerequisites.first!.description)."
            })
        )
        #expect(foundButton.title(for: .normal) == "Enable \(missingPrerequisites.first!.description) prerequisite")
    }
    
    @Test("didTapAllow triggers orchestrator resolve function")
    func didTapAllowTriggersResolve() {
        // Given
        #expect(mockOrchestrator.resolveCalled == false)
        _ = sut.view
        
        // When
        sut.didTapAllow()

        // Then
        #expect(mockOrchestrator.resolveCalled == true)
    }
}
