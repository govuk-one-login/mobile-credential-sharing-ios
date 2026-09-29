import SharingCameraService
import SharingCryptoService
import SharingOrchestration
import Testing
internal import UIKit

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("VerifierViewControllerTests")
struct VerifierViewControllerTests {

    @Test("Static content and defaults are configured")
    func staticContentAndDefaults() throws {
        let sut = VerifierViewController()
        _ = sut.view

        let attributeMenu = try #require(
            findButton(in: sut.view, identifier: VerifierViewController.attributeGroupMenuIdentifier)
        )
        let readerAuthMenu = try #require(
            findButton(in: sut.view, identifier: VerifierViewController.readerAuthMenuIdentifier)
        )
        let verifyButton = try #require(
            findButton(in: sut.view, identifier: VerifierViewController.verifyCredentialIdentifier)
        )

        // Each drop-down shows its default option's title.
        #expect(attributeMenu.title(for: .normal) == VerifierAttributeOption.default.displayName)
        #expect(readerAuthMenu.title(for: .normal) == ReaderAuthProfileOption.default.displayName)
        #expect(sut.selectedAttributeOption == .default)
        #expect(sut.selectedReaderAuthOption == .valid)

        #expect(verifyButton.title(for: .normal) == "Verify Credential")
        #expect(sut.title == "Verifier")
        #expect(sut.restorationIdentifier == "VerifierViewController")
    }

    @Test(
        "Each drop-down is a single-select menu exposing all its options",
        arguments: [
            "AttributeGroupMenuButton",
            "ReaderAuthMenuButton"
        ]
    )
    func dropdownIsSingleSelectWithAllOptions(_ identifier: String) throws {
        let expectedOptionCount: Int
        switch identifier {
        case VerifierViewController.attributeGroupMenuIdentifier:
            expectedOptionCount = VerifierAttributeOption.allCases.count
        case VerifierViewController.readerAuthMenuIdentifier:
            expectedOptionCount = ReaderAuthProfileOption.allCases.count
        default:
            Issue.record("Unexpected menu identifier: \(identifier)")
            return
        }

        let sut = VerifierViewController()
        _ = sut.view

        let menuButton = try #require(findButton(in: sut.view, identifier: identifier))
        let menu = try #require(menuButton.menu)

        #expect(menu.children.count == expectedOptionCount)
        #expect(menu.options.contains(.singleSelection))
    }

    @Test("Each attribute option maps to the expected AttributeGroup")
    func attributeOptionMapping() throws {
        for option in VerifierAttributeOption.allCases {
            let group = try #require(option.attributeGroup)
            #expect(group == expectedAttributeGroup(for: option))
        }
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

    // MARK: - Helpers

    /// The `AttributeGroup` each option is expected to produce, declared independently of the
    /// production mapping so the parameterised test verifies the real behaviour.
    private func expectedAttributeGroup(for option: VerifierAttributeOption) -> AttributeGroup? {
        switch option {
        case .portraitAndAgeOver21:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .portrait, intentToRetain: false),
                    .init(attribute: .ageOver(21), intentToRetain: false)
                ]
            )
        case .portraitNameRetainAndAgeOver18:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .portrait, intentToRetain: true),
                    .init(attribute: .givenName, intentToRetain: true),
                    .init(attribute: .familyName, intentToRetain: true),
                    .init(attribute: .ageOver(18), intentToRetain: false)
                ]
            )
        case .nameMissingPortrait:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .givenName, intentToRetain: false)
                ]
            )
        case .nameTitleRetainAndAgeOver23:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .givenName, intentToRetain: true),
                    .init(attribute: .ageOver(23), intentToRetain: false)
                ],
                gbMdlAttributes: [
                    .init(attribute: .title, intentToRetain: true)
                ]
            )
        }
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
