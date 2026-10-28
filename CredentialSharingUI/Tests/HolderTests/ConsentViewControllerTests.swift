import DesignSystem
import Foundation
import GDSAnalytics
import SharingLogging
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ConsentViewController Tests")
struct ConsentViewControllerTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let analytics = MockAnalyticsService()
    let holderContainer: HolderContainer

    init() {
        holderContainer = HolderContainer(orchestrator: mockOrchestrator)
    }

    private func makeSUT(
        _ attributes: [(String, Bool)] = [("Name", true), ("Photo", false)],
        dvsName: String = "Yoti Ltd."
    ) -> ConsentViewController {
        let presentation = ConsentPresentation(
            dvsName: dvsName,
            documentType: DocumentType(displayLabel: "driving licence", documentIcon: UIImage()),
            attributes: attributes.map {
                ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: $0.0, intentToRetain: $0.1)
            },
            privacyPolicyURL: URL(string: "https://example.gov.uk/privacy")!
        )
        let sut = ConsentViewController(
            presentation: presentation,
            orchestrator: mockOrchestrator,
            container: holderContainer,
            analyticsService: analytics
        )
        sut.loadViewIfNeeded()
        return sut
    }

    // MARK: Helper functions

    private func allLabelTexts(in view: UIView) -> [String] {
        var texts: [String] = []
        if let label = view as? UILabel, let text = label.text { texts.append(text) }
        view.subviews.forEach { texts += allLabelTexts(in: $0) }
        return texts
    }

    private func label(_ text: String, in view: UIView) -> UILabel? {
        if let label = view as? UILabel, label.text == text { return label }
        for sub in view.subviews { if let found = label(text, in: sub) { return found } }
        return nil
    }

    private func button(_ identifier: String, in view: UIView) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityIdentifier == identifier { return button }
        for sub in view.subviews { if let found = button(identifier, in: sub) { return found } }
        return nil
    }

    private func buttonTitle(_ button: UIButton?) -> String? {
        button?.configuration?.title ?? button?.title(for: .normal)
    }

    // MARK: Layout

    @Test("Shows title, DVS sentence and the What you'll share heading")
    func headerCopy() throws {
        let sut = makeSUT()
        let texts = allLabelTexts(in: sut.view)
        #expect(texts.contains("Review what you’ll share"))
        #expect(texts.contains("The person doing the check is using an approved app powered by Yoti Ltd."))
        #expect(texts.contains("What you’ll share"))
        #expect(texts.contains("You’ll share 2 details from your driving licence"))
    }

    @Test("Title and section heading carry the header accessibility trait")
    func headerTraits() throws {
        let sut = makeSUT()
        let title = try #require(label("Review what you’ll share", in: sut.view))
        let heading = try #require(label("What you’ll share", in: sut.view))
        #expect(title.accessibilityTraits.contains(.header))
        #expect(heading.accessibilityTraits.contains(.header))
        #expect(title.adjustsFontForContentSizeCategory)
        #expect(title.numberOfLines == 0)
    }

    @Test("Some-kept variant shows both headed lists (Variant AC3)")
    func someKeptVariant() {
        let texts = allLabelTexts(in: makeSUT().view)
        #expect(texts.contains("Yoti Ltd. will keep these details as a record of this check:"))
        #expect(texts.contains("Yoti Ltd. will not keep:"))
        #expect(texts.contains("Name"))
        #expect(texts.contains("Photo"))
    }

    @Test("No-kept variant shows the not-saved footnote (Variant AC1)")
    func noneKeptVariant() {
        let texts = allLabelTexts(in: makeSUT([("Photo", false)]).view)
        #expect(texts.contains("These details will only be used for this check. They will not be saved."))
        #expect(!texts.contains { $0.contains("will not keep:") })
    }

    @Test("All-kept variant shows the record-of-check footnote (Variant AC2)")
    func allKeptVariant() {
        let texts = allLabelTexts(in: makeSUT([("Name", true)]).view)
        #expect(texts.contains("Yoti Ltd will keep these details as a record of this check."))
        #expect(!texts.contains { $0.contains("will not keep:") })
    }

    @Test("Buttons use GDS components with the design copy")
    func buttons() throws {
        let sut = makeSUT()
        let agree = button(ConsentViewModel.agreeButtonIdentifier, in: sut.view)
        let cancel = button(ConsentViewModel.cancelButtonIdentifier, in: sut.view)
        let readAbout = button(ConsentViewModel.readAboutButtonIdentifier, in: sut.view)
        #expect(buttonTitle(agree) == "Agree and share 2 details")
        #expect(buttonTitle(cancel) == "Cancel and go back to documents")
        #expect(buttonTitle(readAbout) == "Read about Yoti Ltd. and their privacy notice")
    }

    @Test("Deny button is no longer on screen")
    func noDenyButton() {
        let sut = makeSUT()
        func titles(in view: UIView) -> [String] {
            let own = (view as? UIButton).flatMap { $0.configuration?.title ?? $0.title(for: .normal) }
            return (own.map { [$0] } ?? []) + view.subviews.flatMap(titles)
        }
        #expect(!titles(in: sut.view).contains("Deny"))
    }

    @Test("Navigation back button is hidden")
    func backButtonHidden() {
        let sut = makeSUT()
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        #expect(sut.navigationItem.hidesBackButton)
    }

    // MARK: Interactions & analytics

    @Test("Viewing the screen records a screenView with the screen ID (Analytics AC1)")
    func screenView() throws {
        let sut = makeSUT()
        // GDSScreen fires `didAppear` from viewDidAppear
        sut.beginAppearanceTransition(true, animated: false)
        sut.endAppearanceTransition()
        let event = try #require(analytics.loggedEvents.first { $0.name == ScreenViewEventName.screenView.rawValue })
        #expect(event.parameters["screen_id"] as? String == "ac1f2e03-2b4e-4804-8c16-2d18c37b0f9e")
        #expect(event.parameters["screen_name"] as? String == "review what you’ll share")
        #expect(event.parameters["taxonomy_level1"] as? String == "one login mobile application")
        #expect(event.parameters["taxonomy_level2"] as? String == "wallet")
        #expect(event.parameters["taxonomy_level3"] as? String == "proximity sharing")
    }

    @Test("Agree proceeds via userDidTapApprove and tracks the button without the count (Interaction AC1, Analytics AC3)")
    func agreeTapped() throws {
        let sut = makeSUT()
        let agree = try #require(button(ConsentViewModel.agreeButtonIdentifier, in: sut.view))
        agree.sendActions(for: .touchUpInside)

        #expect(mockOrchestrator.userDidTapApproveCalled)
        let event = try #require(analytics.loggedEvents.last)
        #expect(event.name == EventName.navigation.rawValue)
        let text = try #require(event.parameters["text"] as? String)
        #expect(text == "agree and share details")
        #expect(!text.contains { $0.isNumber })
    }

    @Test("Read about tracks a button event and does nothing else (Interaction AC2, Analytics AC2)")
    func readAboutTapped() throws {
        let sut = makeSUT()
        let readAbout = try #require(button(ConsentViewModel.readAboutButtonIdentifier, in: sut.view))
        readAbout.sendActions(for: .touchUpInside)

        #expect(sut.presentedViewController == nil)
        #expect(!mockOrchestrator.userDidTapApproveCalled)
        let text = try #require(analytics.loggedEvents.last?.parameters["text"] as? String)
        #expect(text == "read about dvs and their privacy notice")
        #expect(!text.contains("yoti"))
    }

    @Test("Cancel tracks a button event but is non-functional this ticket (Interaction AC3, Analytics AC4)")
    func cancelTapped() throws {
        let sut = makeSUT()
        let cancel = try #require(button(ConsentViewModel.cancelButtonIdentifier, in: sut.view))
        cancel.sendActions(for: .touchUpInside)
        
        #expect(sut.presentedViewController == nil)
        #expect(!mockOrchestrator.cancelPresentationCalled)
        #expect(!mockOrchestrator.userDidTapDenyCalled)
        // Analytics AC4: a button event is still recorded.
        #expect(analytics.loggedEvents.last?.parameters["text"] as? String == "cancel and go back to documents")
    }
}
