// swiftlint:disable file_length
import CredentialSharingTestUtilities
import Foundation
import SafariServices
import SharingCryptoService
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ConsentViewController Tests")
// swiftlint:disable type_body_length
struct ConsentViewControllerTests {
    let mockOrchestrator: MockHolderOrchestrator

    init() {
        self.mockOrchestrator = MockHolderOrchestrator()
    }

    @Test("View loads with correct title")
    func viewLoadsWithTitle() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let titleLabel = try #require(sut.view.subviews.first {
            ($0 as? UILabel)?.text == "Confirm the credential attributes to share"
        } as? UILabel)

        #expect(titleLabel.font == UIFont.systemFont(ofSize: 24, weight: .bold))
        #expect(titleLabel.textAlignment == .center)
    }

    @Test("View contains text view with filter result details")
    func viewContainsTextView() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let textView = sut.attributesTextView
        #expect(textView.isEditable == false)
        #expect(textView.isScrollEnabled == true)
    }

    @Test("Footer text view displays the organisation sentence (AC6)")
    func textViewDisplaysOrganisationSentence() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        #expect(
            sut.footerTextView.text?.contains("The person doing the check is using an approved app powered by GDS.") == true
        )
    }

    @Test("Attributes text view displays namespace")
    func textViewDisplaysNamespace() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        #expect(sut.attributesTextView.text?.contains("org.iso.18013.5.1") == true)
    }

    @Test("Attributes text view displays resolved attributes without intent to retain")
    func textViewDisplaysElementsWithoutIntentToRetain() throws {
        let sut = ConsentViewController(
            presentation: makeConsentPresentation(intentToRetain: false),
            orchestrator: mockOrchestrator
        )

        sut.viewDidLoad()

        let text = try #require(sut.attributesTextView.text)

        #expect(text.contains("family_name — will not be kept"))
        #expect(text.contains("portrait — will not be kept"))
    }

    @Test("Attributes text view displays resolved attributes with intent to retain")
    func textViewDisplaysElementsWithIntentToRetain() throws {
        let sut = ConsentViewController(
            presentation: makeConsentPresentation(intentToRetain: true),
            orchestrator: mockOrchestrator
        )

        sut.viewDidLoad()

        let text = try #require(sut.attributesTextView.text)

        #expect(text.contains("family_name — will be kept by the verifier"))
    }

    // MARK: - AC5: Privacy-policy link

    @Test("Footer text view renders the privacy-policy label text (AC5)")
    func textViewDisplaysPrivacyPolicyLabel() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        #expect(sut.footerTextView.text?.contains("Privacy policy") == true)
    }

    @Test("Privacy-policy text carries a link attribute pointing at the verified URL (AC5)")
    func privacyPolicyHasLinkAttribute() throws {
        let expectedURL = URL(string: "https://example.gov.uk/privacy")!
        let sut = ConsentViewController(
            presentation: makeConsentPresentation(privacyPolicyURL: expectedURL),
            orchestrator: mockOrchestrator
        )

        sut.viewDidLoad()

        let attributedText = try #require(sut.footerTextView.attributedText)

        var foundLink: URL?
        attributedText.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            if let url = value as? URL {
                foundLink = url
            }
        }

        #expect(foundLink == expectedURL)
    }

    @Test("Tapping the privacy-policy link opens an embedded web view and suppresses external open (AC5)")
    func privacyPolicyLinkOpensEmbeddedWebView() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        let shouldInteract = sut.textView(
            sut.footerTextView,
            shouldInteractWith: URL(string: "https://example.gov.uk/privacy")!,
            in: NSRange(location: 0, length: 0),
            interaction: .invokeDefaultAction
        )

        // Returns false so UITextView does not also open the system browser.
        #expect(shouldInteract == false)
        #expect(sut.presentedViewController is SFSafariViewController)
    }

    // MARK: - AC6: dvsName period normalisation

    @Test("dvsName without a trailing period yields exactly one period (AC6)")
    func dvsNameWithoutPeriodNormalises() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        #expect(sut.normaliseDvsName("Yoti Ltd") == "Yoti Ltd")
    }

    @Test("dvsName with a trailing period is normalised to no trailing period (AC6)")
    func dvsNameWithPeriodNormalises() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)
        #expect(sut.normaliseDvsName("Yoti Ltd.") == "Yoti Ltd")
    }

    @Test("Both dvsName variants render an identical single-period sentence (AC6)")
    func dvsNameVariantsRenderIdenticalSentence() throws {
        let withoutPeriod = ConsentViewController(
            presentation: makeConsentPresentation(dvsName: "Yoti Ltd"),
            orchestrator: mockOrchestrator
        )
        let withPeriod = ConsentViewController(
            presentation: makeConsentPresentation(dvsName: "Yoti Ltd."),
            orchestrator: mockOrchestrator
        )

        withoutPeriod.viewDidLoad()
        withPeriod.viewDidLoad()

        let expectedSentence = "The person doing the check is using an approved app powered by Yoti Ltd."

        let textViewWithout = withoutPeriod.footerTextView
        let textViewWith = withPeriod.footerTextView

        #expect(textViewWithout.text?.contains(expectedSentence) == true)
        #expect(textViewWith.text?.contains(expectedSentence) == true)
        // Neither should produce a double period.
        #expect(textViewWithout.text?.contains("Yoti Ltd..") == false)
        #expect(textViewWith.text?.contains("Yoti Ltd..") == false)
    }

    @Test("View contains Accept button")
    func viewContainsAcceptButton() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let acceptButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Accept"
        } as? UIButton)

        #expect(acceptButton.backgroundColor == .systemGreen)
    }

    @Test("View contains Deny button")
    func viewContainsDenyButton() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let denyButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Deny"
        } as? UIButton)

        #expect(denyButton.backgroundColor == .systemRed)
    }

    @Test("Navigation back button is hidden")
    func navigationBackButtonHidden() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        #expect(sut.navigationItem.hidesBackButton == true)
    }

    @Test("Accept button tap calls userDidTapApprove on orchestrator")
    func acceptButtonTapCallsUserDidTapApprove() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)
        sut.loadViewIfNeeded()

        let acceptButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Accept"
        } as? UIButton)

        for target in acceptButton.allTargets {
            for action in acceptButton.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                (target as NSObject).perform(Selector(action), with: acceptButton)
            }
        }

        #expect(mockOrchestrator.userDidTapApproveCalled == true)
    }

    @Test("Deny button tap presents confirmation dialog")
    func denyButtonTapCallsCancelPresentation() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        let denyButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Deny"
        } as? UIButton)

        for target in denyButton.allTargets {
            for action in denyButton.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                (target as NSObject).perform(Selector(action), with: denyButton)
            }
        }

        // Deny button now presents a confirmation dialog rather than directly calling userDidTapDeny
        #expect(mockOrchestrator.userDidTapDenyCalled == false)
        #expect(sut.presentedViewController is UIAlertController)
    }

    @Test("Deny confirmation dialog has correct structure")
    func denyConfirmationDialogStructure() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)

        let window = UIWindow()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.loadViewIfNeeded()

        let denyButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Deny"
        } as? UIButton)

        for target in denyButton.allTargets {
            for action in denyButton.actions(forTarget: target, forControlEvent: .touchUpInside) ?? [] {
                (target as NSObject).perform(Selector(action), with: denyButton)
            }
        }

        let alert = try #require(sut.presentedViewController as? UIAlertController)

        #expect(alert.message == "Are you sure you want to deny this request?")
        #expect(alert.actions.count == 2)
        #expect(alert.actions[0].title == "Deny")
        #expect(alert.actions[0].style == .destructive)
        #expect(alert.actions[1].title == "Cancel")
        #expect(alert.actions[1].style == .cancel)
    }

    @Test("Confirming denial on dialog calls userDidTapDeny on orchestrator")
    func confirmingDenialCallsUserDidTapDeny() throws {
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)
        sut.loadViewIfNeeded()

        sut.confirmDenial()

        #expect(mockOrchestrator.userDidTapDenyCalled == true)
    }

    @Test("Accept and Deny buttons are enabled on load")
    func acceptAndDenyButtonsAreEnabledOnLoad() throws {
        // Given
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)
        sut.loadViewIfNeeded()

        // Then
        #expect(sut.buttons.allSatisfy { $0.isEnabled })
    }

    @Test("Accept and Deny buttons are disabled when a user clicks on accept or deny", arguments: ["denyButtonTapped", "acceptButtonTapped"])
    func acceptAndDenyButtonsAreDisabledOnAcceptOrDeny(_ buttonActionLabel: String) throws {
        // Given
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)
        sut.loadViewIfNeeded()
        let selector = NSSelectorFromString(buttonActionLabel)
        #expect(sut.responds(to: selector))

        // When - User taps on accept or deny
        sut.perform(selector)

        // Then - Both buttons should be disabled
        #expect(sut.buttons.allSatisfy { !$0.isEnabled })
    }

    @Test("Accept and Deny buttons are re-enabled after cancelling the denial")
    func acceptAndDenyButtonsAreEnabledAfterDenialCancellation() throws {
        // Given
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)
        sut.loadViewIfNeeded()

        // When - deny button tapped
        let selector = NSSelectorFromString("denyButtonTapped")
        #expect(sut.responds(to: selector))
        sut.perform(selector)

        // Then - both buttons are disabled
        #expect(sut.buttons.allSatisfy { !$0.isEnabled })

        // When - you cancel out of the alert
        sut.handleCancellation()

        // Then - both buttons are enabled
        #expect(sut.buttons.allSatisfy { $0.isEnabled })
    }

    @Test("Accept and Deny buttons are re-enabled after pressing accept and encountering a recoverable failure")
    func acceptAndDenyAreReEnabledAfterRecoverableFailure() throws {
        // Given
        let sut = ConsentViewController(presentation: makeConsentPresentation(), orchestrator: mockOrchestrator)
        sut.loadViewIfNeeded()

        // When - accept button tapped
        let selector = NSSelectorFromString("acceptButtonTapped")
        #expect(sut.responds(to: selector))
        sut.perform(selector)

        // Then - both buttons are disabled
        #expect(sut.buttons.allSatisfy { !$0.isEnabled })

        // When - the orchestrator fails recoverably (the container forwards this
        // to the consent screen via the ConsentRetryDelegate)
        sut.consentRetryAvailable()

        // Then - both buttons are enabled
        #expect(sut.buttons.allSatisfy { $0.isEnabled })
    }

    // MARK: - Helper Methods

    private func makeConsentPresentation(
        intentToRetain: Bool = false,
        dvsName: String = "GDS",
        privacyPolicyURL: URL = URL(string: "https://example.gov.uk/privacy")!
    ) -> ConsentPresentation {
        ConsentPresentation(
            dvsName: dvsName,
            documentType: DocumentType(displayLabel: "org.iso.18013.5.1.mDL", documentIcon: UIImage()),
            attributes: [
                ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "family_name", intentToRetain: intentToRetain),
                ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "portrait", intentToRetain: false)
            ],
            privacyPolicyURL: privacyPolicyURL
        )
    }
}
// swiftlint:enable type_body_length
