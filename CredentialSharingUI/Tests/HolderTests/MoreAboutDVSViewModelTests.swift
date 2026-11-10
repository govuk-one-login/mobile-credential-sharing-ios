import DesignSystem
import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("More About DVS Screen Tests")
struct MoreAboutDVSViewModelTests {
    let analyticsService = MockAnalyticsService()

    private func makeViewModel(
        onClose: @escaping () -> Void = {}
    ) -> MoreAboutDVSViewModel {
        MoreAboutDVSViewModel(
            presentation: ConsentPresentation(
                dvsName: "Yoti Ltd",
                documentType: DocumentType(
                    displayLabel: "Driving Licence",
                    documentIcon: UIImage()
                ),
                attributes: [],
                privacyPolicyURL: URL(string: "https://example.com/privacy")!
            ),
            analyticsService: analyticsService,
            onClose: onClose
        )
    }

    private func buttons(in viewModel: MoreAboutDVSViewModel) -> [GDSButtonViewModel] {
        viewModel.body.compactMap { $0 as? GDSButtonViewModel }
    }

    private func textViewModels(in viewModel: MoreAboutDVSViewModel) -> [GDSTextViewModel] {
        viewModel.body.compactMap { $0 as? GDSTextViewModel }
    }

    private func lists(in viewModel: MoreAboutDVSViewModel) -> [GDSListViewModel] {
        viewModel.body.compactMap { $0 as? GDSListViewModel }
    }

    // MARK: - Layout composition

    @Test("Body is title, intro, required certifications list, privacy title, privacy list, then privacy link")
    func bodyComposition() {
        let viewModel = makeViewModel()
        #expect(viewModel.body.count == 6)

        let textIdentifiers = textViewModels(in: viewModel).map { $0.accessibilityIdentifier }
        #expect(textIdentifiers == [
            "more-about-dvs-title",
            "more-about-dvs-intro",
            "dvs-privacy-policy-title"
        ])

        let listIdentifiers = lists(in: viewModel).map { $0.accessibilityIdentifier }
        #expect(listIdentifiers == [
            "dvs-required-certification-list",
            "dvs-privacy-notice-list"
        ])

        #expect(buttons(in: viewModel).count == 1)
    }

    @Test("There are no footer or movable footer items")
    func noFooterItems() {
        let viewModel = makeViewModel()
        #expect(viewModel.footer.isEmpty)
        #expect(viewModel.movableFooter.isEmpty)
    }

    @Test("Required certifications is a three-item bulleted list")
    func requiredCertificationsList() throws {
        let viewModel = makeViewModel()
        let list = try #require(lists(in: viewModel).first)

        #expect(list.style == .bulleted)
        #expect(list.items.count == 3)
        #expect(list.title?.stringKey == "requiredCertificationListTitle")
        #expect(list.accessibilityIdentifier == "dvs-required-certification-list")
    }

    @Test("Privacy notice is a two-item bulleted list")
    func privacyNoticeList() throws {
        let viewModel = makeViewModel()
        let list = try #require(lists(in: viewModel).last)

        #expect(list.style == .bulleted)
        #expect(list.items.count == 2)
        #expect(list.title?.stringKey == "dvsPrivacyNoticeListTitle")
        #expect(list.accessibilityIdentifier == "dvs-privacy-notice-list")
    }

    // MARK: - Cancel/close bar button

    @Test("Right bar button is a Close button")
    func closeBarButton() throws {
        let buttons = try #require(makeViewModel().rightBarButtons)
        #expect(buttons.count == 1)
        let button = try #require(buttons.first)
        #expect(button.accessibilityIdentifier == "more-about-dvs-close-button")
    }

    @Test("Back button is hidden")
    func backButtonHidden() {
        #expect(makeViewModel().backButtonIsHidden)
    }

    // MARK: - Interaction & Analytics

    @Test("Close returns to the consent screen and tracks the close event")
    func closeReturnsToConsent() throws {
        var onCloseCalled = false
        let viewModel = makeViewModel { onCloseCalled = true }

        #expect(analyticsService.trackedEvents.isEmpty)

        let closeButton = try #require(viewModel.rightBarButtons?.first)
        let action = try #require(closeButton.action)
        action()

        // Close navigates back to consent via onClose
        #expect(onCloseCalled)

        // didDismiss is unused: close is driven entirely by the bar button action.
        #expect(viewModel.didDismiss == nil)

        #expect(analyticsService.trackedEvents == [.close])
    }

    @Test("Privacy notice link tracks the privacy policy link event")
    func privacyNoticeLinkTracksEvent() throws {
        let viewModel = makeViewModel()
        let link = try #require(buttons(in: viewModel).first)

        #expect(analyticsService.trackedEvents.isEmpty)

        if case let .action(action) = link.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous .action for the privacy notice link")
        }

        #expect(analyticsService.trackedEvents == [.dvsPrivacyPolicyLink])
    }

    @Test("didAppear logs the screen view")
    func didAppearTracksScreenVisit() throws {
        let viewModel = makeViewModel()

        #expect(analyticsService.trackedScreens.isEmpty)

        if case let .action(action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.trackedScreens == [.moreAboutDVS])
    }
}
