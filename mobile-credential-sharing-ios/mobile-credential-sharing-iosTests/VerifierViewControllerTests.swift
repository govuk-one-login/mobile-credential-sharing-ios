import CameraService
import Testing
internal import UIKit

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("VerifierViewControllerTests")
struct VerifierViewControllerTests {

    @Test("All necessary subviews are present and configured")
    func checkViewSetupCorrectly() throws {
        let sut = VerifierViewController()
        _ = sut.view

        let scanButton = sut.view.subviews.first {
            $0.accessibilityIdentifier == VerifierViewController.scanButtonIdentifier
        }
        let foundButton = try #require(scanButton as? UIButton)

        #expect(foundButton.title(for: .normal) == "Scan Credential")
        #expect(sut.title == "Verifier")
        #expect(sut.restorationIdentifier == "VerifierViewController")
    }

    @Test("Required init with coder successfully creates instance")
    func initWithCoderCreatesInstance() throws {
        // Arrange: Create properly encoded data for NSKeyedUnarchiver
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let validData = archiver.encodedData

        let coder = try NSKeyedUnarchiver(forReadingFrom: validData)

        // Act: Initialize using the required init(coder:) method
        let sut = VerifierViewController(coder: coder)

        // Assert: Verify the instance was created successfully
        let foundViewController = try #require(sut)
        _ = foundViewController.view

        #expect(foundViewController.title == "Verifier")
        #expect(foundViewController.restorationIdentifier == "VerifierViewController")
    }
}
