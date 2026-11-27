import CredentialSharingTestFixtures
import DesignSystem
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
        #expect(makeGenericErrorViewModel().bodyParagraphCount == 2)
    }

    @Test("Generic error screen has a single 'Go back to documents' button")
    func genericErrorButtons() throws {
        let viewModel = makeGenericErrorViewModel()

        #expect(viewModel.buttons.count == 1)
        let button = try #require(viewModel.buttons.first)
        #expect(button.title.forState(.normal) == "Go back to documents")
        #expect(viewModel.buttonAccessibilityIdentifiers == ["generic-error-go-back-button"])
    }

    @Test("Rendered buttons use the screen-specific accessibility identifiers")
    func renderedButtonsUseScreenSpecificIdentifiers() throws {
        let sut = ResolutionFailureViewController(viewModel: makeGenericErrorViewModel())
        _ = sut.view

        #expect(findView(in: sut.view, withAccessibilityIdentifier: "generic-error-go-back-button") is UIButton)
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
        let button = try #require(viewModel.buttons.first)

        #expect(mockOrchestrator.userDidFinishCalled == false)
        #expect(analyticsService.trackedEvents.isEmpty)

        button.tap()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.goBackToDocumentsButton])
    }

    // MARK: - Analytics

    @Test("didAppear tracks the generic error screen with the error description as the reason")
    func didAppearTracksGenericErrorScreenWithReason() {
        let viewModel = makeGenericErrorViewModel(errorDescription: "Credential signing failed")

        #expect(analyticsService.trackedScreens.isEmpty)

        viewModel.appear()

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

        viewModel.appear()

        #expect(analyticsService.trackedErrorDescriptions == [nil])
    }

    // MARK: - ReaderAuth error

    private func makeReaderAuthErrorViewModel(
        errorDescription: String = "Reader Authentication failed: untrustedReaderCertificate"
    ) -> ResolutionFailureViewModel {
        .readerAuthError(
            errorDescription: errorDescription,
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService
        )
    }

    @Test("ReaderAuth error screen shows the 'There is a problem' title and two body paragraphs")
    func readerAuthErrorContent() {
        let viewModel = makeReaderAuthErrorViewModel()

        #expect(viewModel.title.value == "There is a problem")
        #expect(viewModel.bodyParagraphCount == 2)
    }

    @Test("ReaderAuth error screen has a single 'Go back to documents' button with its own identifier")
    func readerAuthErrorButtons() throws {
        let viewModel = makeReaderAuthErrorViewModel()

        #expect(viewModel.buttons.count == 1)
        let button = try #require(viewModel.buttons.first)
        #expect(button.title.forState(.normal) == "Go back to documents")
        #expect(viewModel.buttonAccessibilityIdentifiers == ["reader-auth-error-go-back-button"])
    }

    @Test("ReaderAuth error 'Go back to documents' finishes the journey without cancel confirmation and tracks the event")
    func readerAuthErrorGoBackFinishesJourneyAndTracksEvent() throws {
        let viewModel = makeReaderAuthErrorViewModel()
        let button = try #require(viewModel.buttons.first)

        button.tap()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.goBackToDocumentsButton])
    }

    @Test("ReaderAuth error didAppear tracks its screen with the error description as the reason")
    func readerAuthErrorDidAppearTracksScreenWithReason() {
        let viewModel = makeReaderAuthErrorViewModel(errorDescription: "Reader Authentication failed: invalidReaderSignature")

        viewModel.appear()

        #expect(analyticsService.trackedScreens == [.readerAuthError])
        #expect(analyticsService.trackedErrorDescriptions == ["Reader Authentication failed: invalidReaderSignature"])
    }

    // MARK: - Bluetooth off error

    private func makeBluetoothOffErrorViewModel(
        errorDescription: String = "Bluetooth was turned off during the session"
    ) -> ResolutionFailureViewModel {
        .bluetoothOffError(
            errorDescription: errorDescription,
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService
        )
    }

    // MARK: - Unfulfillable request

    private func makeUnfulfillableRequestViewModel(
        errorDescription: String = "The request cannot be fulfilled"
    ) -> ResolutionFailureViewModel {
        .unfulfillableRequest(
            errorDescription: errorDescription,
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService
        )
    }

    @Test("Bluetooth off error screen shows its title and three body paragraphs")
    func bluetoothOffErrorContent() {
        let viewModel = makeBluetoothOffErrorViewModel()

        #expect(viewModel.title.value == "Bluetooth is turned off")
        #expect(viewModel.bodyParagraphCount == 3)
    }

    @Test("Bluetooth off error screen has Continue then Cancel buttons with their own identifiers")
    func bluetoothOffErrorButtons() {
        let viewModel = makeBluetoothOffErrorViewModel()

        #expect(viewModel.buttonTitles == ["Continue", "Cancel and go back to documents"])
        #expect(viewModel.buttonAccessibilityIdentifiers == [
            "bluetooth-off-error-continue-button",
            "bluetooth-off-error-cancel-button"
        ])
    }

    @Test("Bluetooth off error Continue starts a new session and tracks the event")
    func bluetoothOffErrorContinueStartsNewSession() throws {
        let viewModel = makeBluetoothOffErrorViewModel()
        let button = try #require(viewModel.buttons.first)

        button.tap()

        #expect(mockOrchestrator.startPresentationCalled)
        #expect(mockOrchestrator.userDidFinishCalled == false)
        #expect(analyticsService.trackedEvents == [.continueButton])
    }

    @Test("Bluetooth off error Cancel finishes the journey without confirmation and tracks the event")
    func bluetoothOffErrorCancelFinishesJourney() throws {
        let viewModel = makeBluetoothOffErrorViewModel()
        let button = try #require(viewModel.buttons.last)

        button.tap()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(mockOrchestrator.startPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.cancelAndGoBackButton])
    }

    @Test("Bluetooth off error didAppear tracks its screen with the error description as the reason")
    func bluetoothOffErrorDidAppearTracksScreenWithReason() {
        let viewModel = makeBluetoothOffErrorViewModel()

        viewModel.appear()

        #expect(analyticsService.trackedScreens == [.bluetoothOffError])
        #expect(analyticsService.trackedErrorDescriptions == ["Bluetooth was turned off during the session"])
    }

    @Test("Unfulfillable request screen shows the 'Details requested not available' title and two separate body paragraphs")
    func unfulfillableRequestContent() {
        let viewModel = makeUnfulfillableRequestViewModel()

        #expect(viewModel.title.value == "Details requested not available")
        #expect(viewModel.bodyParagraphCount == 2)
    }

    @Test("Unfulfillable request screen has a single 'Go back to documents' button with its own identifier")
    func unfulfillableRequestButtons() throws {
        let viewModel = makeUnfulfillableRequestViewModel()

        #expect(viewModel.buttons.count == 1)
        let button = try #require(viewModel.buttons.first)
        #expect(button.title.forState(.normal) == "Go back to documents")
        #expect(viewModel.buttonAccessibilityIdentifiers == ["unfulfillable-request-go-back-button"])
    }

    @Test("Unfulfillable request 'Go back to documents' finishes the journey and tracks the event")
    func unfulfillableRequestGoBackFinishesJourneyAndTracksEvent() throws {
        let viewModel = makeUnfulfillableRequestViewModel()
        let button = try #require(viewModel.buttons.first)

        button.tap()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.goBackToDocumentsButton])
    }

    @Test("Unfulfillable request didAppear tracks its screen with the error description as the reason")
    func unfulfillableRequestDidAppearTracksScreen() {
        let viewModel = makeUnfulfillableRequestViewModel(errorDescription: "No supported document type")

        viewModel.appear()

        #expect(analyticsService.trackedScreens == [.unfulfillableRequest])
        #expect(analyticsService.trackedErrorDescriptions == ["No supported document type"])
    }

    // MARK: - Screen

    @Test("ResolutionFailureViewController loads with the generic error view model")
    func errorScreenLoads() {
        let sut = ResolutionFailureViewController(viewModel: makeGenericErrorViewModel())
        _ = sut.view

        #expect(sut.failureViewModel.title.value == "Sharing is currently unavailable")
        #expect(sut.viewModel is ResolutionFailureViewModel)
    }

    @Test("VoiceOver reads the 'Error' prefix and title as one element")
    func voiceOverLabelIsPrefixAndTitle() throws {
        let sut = ResolutionFailureViewController(viewModel: makeGenericErrorViewModel())
        _ = sut.view

        let element = try #require(
            findView(in: sut.view, withAccessibilityIdentifier: "error-screen-icon-title-stack-view")
        )
        #expect(element.isAccessibilityElement)
        #expect(element.accessibilityLabel == "Error: Sharing is currently unavailable")
    }

    @Test("The decorative icon is hidden from VoiceOver")
    func iconIsHiddenFromVoiceOver() throws {
        let sut = ResolutionFailureViewController(viewModel: makeGenericErrorViewModel())
        _ = sut.view

        let icon = try #require(
            findView(in: sut.view, withAccessibilityIdentifier: "error-screen-icon")
        )
        #expect(icon.isAccessibilityElement == false)
        // Hidden outright so VoiceOver's Image Descriptions can't append a generated
        // description to the "Error: <title>" label.
        #expect(icon.accessibilityElementsHidden)
        #expect(icon.accessibilityTraits == .none)
    }

    @Test("Both buttons of a two-button failure screen are rendered in order")
    func twoButtonScreenRendersBothButtons() throws {
        let viewModel = ResolutionFailureViewModel.bluetoothOffError(
            errorDescription: "Bluetooth was turned off during the session",
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService
        )
        let sut = ResolutionFailureViewController(viewModel: viewModel)
        _ = sut.view

        #expect(findView(in: sut.view, withAccessibilityIdentifier: "bluetooth-off-error-continue-button") is UIButton)
        #expect(findView(in: sut.view, withAccessibilityIdentifier: "bluetooth-off-error-cancel-button") is UIButton)
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

// MARK: - Test helpers

private extension ResolutionFailureViewModel {
    /// Body items after the leading icon-and-title element.
    var bodyParagraphCount: Int { body.count - 1 }
    var buttons: [GDSButtonViewModel] { movableFooter.compactMap { $0 as? GDSButtonViewModel } }
    var buttonTitles: [String] { buttons.map { $0.title.forState(.normal) } }
    var buttonAccessibilityIdentifiers: [String?] { buttons.map(\.accessibilityIdentifier) }

    func appear() {
        if case .action(let action)? = didAppear { action() }
    }
}

private extension GDSButtonViewModel {
    func tap() {
        if case .action(let action) = buttonAction { action() }
    }
}
