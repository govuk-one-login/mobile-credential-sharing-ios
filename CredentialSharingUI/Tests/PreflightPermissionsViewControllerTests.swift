import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("PreflightPermissionViewController Tests")
struct PreflightPermissionViewControllerTests {
    var mockOrchestrator = MockHolderOrchestrator()
    var missingCapability: MissingCapability? = MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthNotDetermined)
    var sut: PreflightPermissionViewController {
        PreflightPermissionViewController([missingCapability!], mockOrchestrator)
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
        let missingCapability = try #require(missingCapability)
        // Then
        #expect(sut.view.subviews.count == 2)
        #expect(
            sut.view.subviews.contains(where: {
                $0 is UILabel && ($0 as? UILabel)?.text == "This app needs to access your \(missingCapability.description)."
            })
        )
        #expect(foundButton.title(for: .normal) == "Enable \(missingCapability.description) permissions")
    }
    
    @Test("didTapAllow triggers orchestrator requestPermissions function")
    func didTapAllowTriggersRequestPermissions() {
        // Given
        #expect(mockOrchestrator.requestPermissionCalled == false)
        _ = sut.view
        
        // When
        sut.didTapAllow()

        // Then
        #expect(mockOrchestrator.requestPermissionCalled == true)
    }
}
