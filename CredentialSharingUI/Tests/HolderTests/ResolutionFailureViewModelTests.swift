import CredentialSharingTestFixtures
import GDSCommon
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ResolutionFailureViewModel Tests")
struct ResolutionFailureViewModelTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let analyticsService = MockSharingAnalyticsService()

    private func makeGenericErrorViewModel(
        errorDescription: String = "Credential signing failed"
    ) -> ResolutionFailureViewModel {
        .genericError(
            errorDescription: errorDescription,
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService
        )
    }

    // MARK: - Content

    @Test("Generic error screen shows the sharing unavailable title")
    func genericErrorTitle() {
        #expect(makeGenericErrorViewModel().title.value == "Sharing is currently unavailable")
    }

    @Test("Generic error screen has two body paragraphs")
    func genericErrorBody() {
        #expect(makeGenericErrorViewModel().bodyContent.count == 2)
    }

    @Test("Generic error screen has a single 'Go back to documents' button")
    func genericErrorButtons() throws {
        let viewModel = makeGenericErrorViewModel()

        #expect(viewModel.buttonViewModels.count == 1)
        let button = try #require(viewModel.buttonViewModels.first)
        #expect(button.title.value == "Go back to documents")
    }

    @Test("Generic error screen has no Cancel bar button and hides the back button")
    func genericErrorHasNoCancelOrBack() {
        let viewModel = makeGenericErrorViewModel()

        #expect(viewModel.rightBarButtonTitle == nil)
        #expect(viewModel.backButtonIsHidden)
    }

    // MARK: - Interaction

    @Test("Tapping 'Go back to documents' finishes the journey and tracks the button event")
    func goBackButtonFinishesJourneyAndTracksEvent() throws {
        let viewModel = makeGenericErrorViewModel()
        let button = try #require(viewModel.buttonViewModels.first)

        #expect(mockOrchestrator.userDidFinishCalled == false)
        #expect(analyticsService.trackedEvents.isEmpty)

        button.action()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.goBackToDocumentsButton])
    }

    // MARK: - Analytics

    @Test("didAppear tracks the generic error screen with the error description as the reason")
    func didAppearTracksGenericErrorScreenWithReason() {
        let viewModel = makeGenericErrorViewModel(errorDescription: "Credential signing failed")

        #expect(analyticsService.trackedScreens.isEmpty)

        viewModel.didAppear()

        #expect(analyticsService.trackedScreens == [.genericError])
        #expect(analyticsService.trackedErrorDescriptions == ["Credential signing failed"])
    }

    @Test("didAppear without an error description tracks no reason")
    func didAppearWithoutDescriptionTracksNoReason() {
        let viewModel = ResolutionFailureViewModel(
            screen: .genericError,
            bodyKeys: [],
            buttons: [],
            analyticsService: analyticsService
        )

        viewModel.didAppear()

        #expect(analyticsService.trackedErrorDescriptions == [nil])
    }

    // MARK: - Screen

    @Test("GDSErrorScreen loads with the generic error view model")
    func errorScreenLoads() {
        let sut = GDSErrorScreen(viewModel: makeGenericErrorViewModel())
        _ = sut.view

        #expect(sut.viewModel.title.value == "Sharing is currently unavailable")
        #expect(sut.viewModel is ResolutionFailureViewModel)
    }

    @Test("VoiceOver reads only the title, without the icon's 'Error' prefix")
    func voiceOverLabelIsTitleOnly() throws {
        let viewModel = makeGenericErrorViewModel()
        let sut = GDSErrorScreen.resolutionFailure(viewModel: viewModel)

        let element = try #require(
            findView(in: sut.view, withAccessibilityIdentifier: "error-screen-icon-title-stack-view")
        )
        #expect(element.accessibilityLabel == "Sharing is currently unavailable")
    }

    @Test("The decorative icon is hidden from VoiceOver")
    func iconIsHiddenFromVoiceOver() throws {
        let sut = GDSErrorScreen.resolutionFailure(viewModel: makeGenericErrorViewModel())

        let icon = try #require(
            findView(in: sut.view, withAccessibilityIdentifier: "error-screen-image")
        )
        #expect(icon.isAccessibilityElement == false)
        #expect(icon.accessibilityElementsHidden)
        #expect(icon.accessibilityTraits == .none)
    }

    private func findView(in view: UIView, withAccessibilityIdentifier identifier: String) -> UIView? {
        if view.accessibilityIdentifier == identifier { return view }
        for subview in view.subviews {
            if let match = findView(in: subview, withAccessibilityIdentifier: identifier) {
                return match
            }
        }
        return nil
    }
}
