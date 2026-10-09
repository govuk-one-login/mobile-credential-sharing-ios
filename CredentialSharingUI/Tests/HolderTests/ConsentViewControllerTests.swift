import Foundation
import SharingCryptoService
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ConsentViewController Tests")
struct ConsentViewControllerTests {
    let mockOrchestrator = MockHolderOrchestrator()

    @Test("View loads with correct title")
    func viewLoadsWithTitle() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let titleLabel = try #require(sut.view.subviews.first {
            ($0 as? UILabel)?.text == "Confirm the credential attributes to share"
        } as? UILabel)

        #expect(titleLabel.font == UIFont.systemFont(ofSize: 24, weight: .bold))
        #expect(titleLabel.textAlignment == .center)
    }

    @Test("View contains text view with filter result details")
    func viewContainsTextView() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        #expect(textView.isEditable == false)
        #expect(textView.isScrollEnabled == true)
    }

    @Test("Text view displays document type")
    func textViewDisplaysDocumentType() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        #expect(textView.text?.contains("Document Type: org.iso.18013.5.1.mDL") == true)
    }

    @Test("Text view displays namespace")
    func textViewDisplaysNamespace() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        #expect(textView.text?.contains("Namespace: org.iso.18013.5.1") == true)
    }

    @Test("Text view displays resolved attributes without intent to retain")
    func textViewDisplaysElementsWithoutIntentToRetain() throws {
        let sut = ConsentViewController(
            filterResult: makeFilterResult(intentToRetain: false),
            orchestrator: mockOrchestrator
        )

        sut.viewDidLoad()

        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        let text = try #require(textView.text)

        #expect(text.contains("family_name: IntentToRetain = false"))
        #expect(text.contains("portrait: IntentToRetain = false"))
    }

    @Test("Text view displays resolved attributes with intent to retain")
    func textViewDisplaysElementsWithIntentToRetain() throws {
        let sut = ConsentViewController(
            filterResult: makeFilterResult(intentToRetain: true),
            orchestrator: mockOrchestrator
        )

        sut.viewDidLoad()

        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        let text = try #require(textView.text)

        #expect(text.contains("family_name: IntentToRetain = true"))
    }

    @Test("View contains Accept button")
    func viewContainsAcceptButton() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let acceptButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Accept"
        } as? UIButton)

        #expect(acceptButton.backgroundColor == .systemGreen)
    }

    @Test("View contains Deny button")
    func viewContainsDenyButton() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        let denyButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Deny"
        } as? UIButton)

        #expect(denyButton.backgroundColor == .systemRed)
    }

    @Test("Navigation back button is hidden")
    func navigationBackButtonHidden() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

        sut.viewDidLoad()

        #expect(sut.navigationItem.hidesBackButton == true)
    }

    @Test("Accept button tap calls userDidTapApprove on orchestrator")
    func acceptButtonTapCallsUserDidTapApprove() throws {
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)
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
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

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
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)

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
        let sut = ConsentViewController(filterResult: makeFilterResult(), orchestrator: mockOrchestrator)
        sut.loadViewIfNeeded()

        sut.confirmDenial()

        #expect(mockOrchestrator.userDidTapDenyCalled == true)
    }

    // MARK: - Helper Methods

    private func makeFilterResult(intentToRetain: Bool = false) -> FilterResult {
        FilterResult(
            issuerSigned: IssuerSigned(nameSpaces: [:], issuerAuth: []),
            docType: "org.iso.18013.5.1.mDL",
            retention: [
                "org.iso.18013.5.1": [
                    "family_name": intentToRetain,
                    "portrait": false
                ]
            ]
        )
    }
}
