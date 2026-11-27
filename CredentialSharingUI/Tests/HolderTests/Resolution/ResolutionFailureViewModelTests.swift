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
        #expect(viewModel.buttonAccessibilityIdentifiers == ["generic-error-go-back-button"])
    }

    @Test("Rendered buttons use the screen-specific accessibility identifiers")
    func renderedButtonsUseScreenSpecificIdentifiers() throws {
        let sut = GDSErrorScreen.resolutionFailure(viewModel: makeGenericErrorViewModel())

        let button = try #require(
            findView(in: sut.view, withAccessibilityIdentifier: "generic-error-go-back-button") as? UIButton
        )
        #expect(button.title(for: .normal) == "Go back to documents")
        // The component's generic identifier has been replaced.
        #expect(findView(in: sut.view, withAccessibilityIdentifier: "error-screen-button-0") == nil)
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
        #expect(viewModel.bodyContent.count == 2)
    }

    @Test("ReaderAuth error screen has a single 'Go back to documents' button with its own identifier")
    func readerAuthErrorButtons() throws {
        let viewModel = makeReaderAuthErrorViewModel()

        #expect(viewModel.buttonViewModels.count == 1)
        let button = try #require(viewModel.buttonViewModels.first)
        #expect(button.title.value == "Go back to documents")
        #expect(viewModel.buttonAccessibilityIdentifiers == ["reader-auth-error-go-back-button"])
    }

    @Test("ReaderAuth error 'Go back to documents' finishes the journey without cancel confirmation and tracks the event")
    func readerAuthErrorGoBackFinishesJourneyAndTracksEvent() throws {
        let viewModel = makeReaderAuthErrorViewModel()
        let button = try #require(viewModel.buttonViewModels.first)

        button.action()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.goBackToDocumentsButton])
    }

    @Test("ReaderAuth error didAppear tracks its screen with the error description as the reason")
    func readerAuthErrorDidAppearTracksScreenWithReason() {
        let viewModel = makeReaderAuthErrorViewModel(errorDescription: "Reader Authentication failed: invalidReaderSignature")

        viewModel.didAppear()

        #expect(analyticsService.trackedScreens == [.readerAuthError])
        #expect(analyticsService.trackedErrorDescriptions == ["Reader Authentication failed: invalidReaderSignature"])
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

    @Test("Unfulfillable request screen shows the 'Details requested not available' title and two separate body paragraphs")
    func unfulfillableRequestContent() {
        let viewModel = makeUnfulfillableRequestViewModel()

        #expect(viewModel.title.value == "Details requested not available")
        #expect(viewModel.bodyContent.count == 2)
    }

    @Test("Unfulfillable request screen has a single 'Go back to documents' button with its own identifier")
    func unfulfillableRequestButtons() throws {
        let viewModel = makeUnfulfillableRequestViewModel()

        #expect(viewModel.buttonViewModels.count == 1)
        let button = try #require(viewModel.buttonViewModels.first)
        #expect(button.title.value == "Go back to documents")
        #expect(viewModel.buttonAccessibilityIdentifiers == ["unfulfillable-request-go-back-button"])
    }

    @Test("Unfulfillable request 'Go back to documents' finishes the journey and tracks the event")
    func unfulfillableRequestGoBackFinishesJourneyAndTracksEvent() throws {
        let viewModel = makeUnfulfillableRequestViewModel()
        let button = try #require(viewModel.buttonViewModels.first)

        button.action()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.goBackToDocumentsButton])
    }

    @Test("Unfulfillable request didAppear tracks its screen with the error description as the reason")
    func unfulfillableRequestDidAppearTracksScreen() {
        let viewModel = makeUnfulfillableRequestViewModel(errorDescription: "No supported document type")

        viewModel.didAppear()

        #expect(analyticsService.trackedScreens == [.unfulfillableRequest])
        #expect(analyticsService.trackedErrorDescriptions == ["No supported document type"])
    }

    // MARK: - Bluetooth connection error

    private func makeBluetoothConnectionErrorViewModel(
        errorDescription: String = "BLE connection dropped, or the remote device became unreachable"
    ) -> ResolutionFailureViewModel {
        .bluetoothConnectionError(
            errorDescription: errorDescription,
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService
        )
    }

    @Test("Bluetooth connection error screen shows its title and three body paragraphs")
    func bluetoothConnectionErrorContent() {
        let viewModel = makeBluetoothConnectionErrorViewModel()

        #expect(viewModel.title.value == "Problem with your Bluetooth connection")
        #expect(viewModel.bodyContent.count == 3)
    }

    @Test("Bluetooth connection error screen has 'Try again' and 'Cancel' buttons")
    func bluetoothConnectionErrorButtons() {
        let viewModel = makeBluetoothConnectionErrorViewModel()

        #expect(viewModel.buttonViewModels.map(\.title.value) == [
            "Try again with a new QR code",
            "Cancel and go back to documents"
        ])
        #expect(viewModel.buttonAccessibilityIdentifiers == [
            "bluetooth-connection-error-try-again-button",
            "bluetooth-connection-error-cancel-button"
        ])
    }

    @Test("Bluetooth connection error 'Try again' restarts the journey and tracks the event")
    func bluetoothConnectionErrorTryAgainRestartsJourney() throws {
        let viewModel = makeBluetoothConnectionErrorViewModel()

        viewModel.buttonViewModels[0].action()

        #expect(mockOrchestrator.startPresentationCalled)
        #expect(mockOrchestrator.userDidFinishCalled == false)
        #expect(analyticsService.trackedEvents == [.tryAgainWithNewQRCodeButton])
    }

    @Test("Bluetooth connection error 'Cancel' finishes the journey without confirmation and tracks the event")
    func bluetoothConnectionErrorCancelFinishesJourney() throws {
        let viewModel = makeBluetoothConnectionErrorViewModel()

        viewModel.buttonViewModels[1].action()

        #expect(mockOrchestrator.userDidFinishCalled)
        #expect(mockOrchestrator.startPresentationCalled == false)
        #expect(mockOrchestrator.cancelPresentationCalled == false)
        #expect(analyticsService.trackedEvents == [.cancelAndGoBackButton])
    }

    @Test("Bluetooth connection error didAppear tracks its screen with the error description as the reason")
    func bluetoothConnectionErrorDidAppearTracksScreenWithReason() {
        let viewModel = makeBluetoothConnectionErrorViewModel()

        viewModel.didAppear()

        #expect(analyticsService.trackedScreens == [.bluetoothConnectionError])
        #expect(analyticsService.trackedErrorDescriptions == [
            "BLE connection dropped, or the remote device became unreachable"
        ])
    }

    // MARK: - Screen

    @Test("GDSErrorScreen loads with the generic error view model")
    func errorScreenLoads() {
        let sut = GDSErrorScreen(viewModel: makeGenericErrorViewModel())
        _ = sut.view

        #expect(sut.viewModel.title.value == "Sharing is currently unavailable")
        #expect(sut.viewModel is ResolutionFailureViewModel)
    }

    @Test("VoiceOver reads the 'Error' prefix and title, without the trailing colon")
    func voiceOverLabelIsPrefixAndTitle() throws {
        let viewModel = makeGenericErrorViewModel()
        let sut = GDSErrorScreen.resolutionFailure(viewModel: viewModel)

        let element = try #require(
            findView(in: sut.view, withAccessibilityIdentifier: "error-screen-icon-title-stack-view")
        )
        #expect(element.accessibilityLabel == "Error: Sharing is currently unavailable")
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

    @Test("The primary button has fully rounded (capsule) corners")
    func primaryButtonIsCapsule() throws {
        let sut = GDSErrorScreen.resolutionFailure(viewModel: makeBluetoothConnectionErrorViewModel())
        sut.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        sut.view.layoutIfNeeded()

        let button = try #require(
            findView(in: sut.view, withAccessibilityIdentifier: "bluetooth-connection-error-try-again-button")
        )
        #expect(button.bounds.height > 0)
        #expect(button.layer.cornerRadius == button.bounds.height / 2)
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
