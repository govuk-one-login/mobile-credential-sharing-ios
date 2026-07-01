import SharingCameraService
import SharingCryptoService
import SharingOrchestration
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

        let option1 = try #require(findButton(in: sut.view, identifier: VerifierViewController.option1Identifier))
        let option2 = try #require(findButton(in: sut.view, identifier: VerifierViewController.option2Identifier))
        let verifyButton = try #require(findButton(in: sut.view, identifier: VerifierViewController.verifyCredentialIdentifier))

        #expect(option1.title(for: .normal) == "Photo and Age Over 21")
        #expect(option2.title(for: .normal) == "Name + Title (Retain) and Age Over 23")
        #expect(verifyButton.title(for: .normal) == "Verify Credential")
        #expect(sut.title == "Verifier")
        #expect(sut.restorationIdentifier == "VerifierViewController")
    }

    @Test("Required init with coder successfully creates instance")
    func initWithCoderCreatesInstance() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let validData = archiver.encodedData

        let coder = try NSKeyedUnarchiver(forReadingFrom: validData)

        let sut = VerifierViewController(coder: coder)

        let foundViewController = try #require(sut)
        _ = foundViewController.view

        #expect(foundViewController.title == "Verifier")
        #expect(foundViewController.restorationIdentifier == "VerifierViewController")
    }

    @Test("Option 1 builds correct AttributeGroup with portrait and age_over_21")
    func option1DataMapping() throws {
        let sut = VerifierViewController()
        _ = sut.view
        sut.selectedOption = 1

        let group = try #require(sut.buildAttributeGroup())

        #expect(group.mdlAttributes.count == 2)
        #expect(group.mdlAttributes[0].attribute == .portrait)
        #expect(group.mdlAttributes[0].intentToRetain == false)
        #expect(group.mdlAttributes[1].attribute == .ageOver(21))
        #expect(group.mdlAttributes[1].intentToRetain == false)
        #expect(group.gbMdlAttributes.isEmpty)
    }

    @Test("Option 2 builds correct AttributeGroup with given_name, title (GB), and age_over_23")
    func option2DataMapping() throws {
        let sut = VerifierViewController()
        _ = sut.view
        sut.selectedOption = 2

        let group = try #require(sut.buildAttributeGroup())

        #expect(group.mdlAttributes.count == 2)
        #expect(group.mdlAttributes[0].attribute == .givenName)
        #expect(group.mdlAttributes[0].intentToRetain == true)
        #expect(group.mdlAttributes[1].attribute == .ageOver(23))
        #expect(group.mdlAttributes[1].intentToRetain == false)
        #expect(group.gbMdlAttributes.count == 1)
        #expect(group.gbMdlAttributes[0].attribute == .title)
        #expect(group.gbMdlAttributes[0].intentToRetain == true)
    }

    @Test("No selection returns nil AttributeGroup")
    func noSelectionReturnsNil() {
        let sut = VerifierViewController()
        _ = sut.view

        #expect(sut.buildAttributeGroup() == nil)
    }

    private func findButton(in view: UIView, identifier: String) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityIdentifier == identifier {
            return button
        }
        for subview in view.subviews {
            if let found = findButton(in: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
}
