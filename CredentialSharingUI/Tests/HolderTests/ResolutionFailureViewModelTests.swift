import CredentialSharingTestFixtures
import GDSCommon
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ResolutionFailureViewModel Tests")
struct ResolutionFailureViewModelTests {
    let mockAnalyticsService = MockSharingAnalyticsService()

    private func makeSUT(
        screen: SharingScreen = .error,
        bodyKey: String = "PLACEHOLDER_failureBody",
        buttons: [FailureButton]
    ) -> ResolutionFailureViewModel {
        ResolutionFailureViewModel(
            screen: screen,
            bodyKey: bodyKey,
            buttons: buttons,
            analyticsService: mockAnalyticsService
        )
    }

    private func goBackButton(_ tapped: @escaping () -> Void = {}) -> FailureButton {
        FailureButton(
            titleKey: "goBackToDocumentsButton",
            event: .goBackToDocumentsButton,
            accessibilityIdentifier: "failure-go-back-button",
            action: tapped
        )
    }

    private func cancelButton(_ tapped: @escaping () -> Void = {}) -> FailureButton {
        FailureButton(
            titleKey: "cancel",
            event: .cancel,
            accessibilityIdentifier: "failure-cancel-button",
            action: tapped
        )
    }

    // MARK: - Composition

    @Test("Uses the fixed error icon")
    func usesErrorIcon() {
        let sut = makeSUT(buttons: [goBackButton()])
        #expect(sut.image == .error)
    }

    @Test("Title resolves from the supplied screen's titleKey")
    func titleFromScreen() {
        let sut = makeSUT(screen: .error, buttons: [goBackButton()])
        // Title is derived from screen.titleKey; the resolved value is driven by
        // the string catalog, so we assert it is non-empty rather than hardcode copy.
        #expect(sut.title.value.isEmpty == false)
    }

    @Test("Body contains a single text item")
    func bodyComposition() {
        let sut = makeSUT(buttons: [goBackButton()])
        #expect(sut.bodyContent.count == 1)
        #expect(sut.bodyContent.first is BodyTextViewModel)
    }

    @Test("No nav-bar controls — buttons live in the error screen's own stack")
    func noNavBarControls() {
        let sut = makeSUT(buttons: [goBackButton()])
        #expect(sut.rightBarButtonTitle == nil)
        #expect(sut.backButtonIsHidden == true)
    }

    @Test("A single supplied button produces a single button view model")
    func singleButton() {
        let sut = makeSUT(buttons: [goBackButton()])
        #expect(sut.buttonViewModels.count == 1)
    }

    @Test("Two supplied buttons produce two button view models in order")
    func twoButtons() {
        let sut = makeSUT(buttons: [goBackButton(), cancelButton()])
        #expect(sut.buttonViewModels.count == 2)
    }

    // MARK: - Analytics

    @Test("didAppear tracks the supplied screen")
    func didAppearTracksScreen() {
        let sut = makeSUT(screen: .error, buttons: [goBackButton()])
        #expect(mockAnalyticsService.trackedScreens.isEmpty)

        sut.didAppear()

        #expect(mockAnalyticsService.trackedScreens == [.error])
    }

    @Test("A button tap tracks its event and then runs its action")
    func buttonTapTracksEventAndRunsAction() throws {
        var didRunAction = false
        let sut = makeSUT(buttons: [goBackButton { didRunAction = true }])
        #expect(mockAnalyticsService.trackedEvents.isEmpty)

        let button = try #require(sut.buttonViewModels.first)
        button.action()

        #expect(mockAnalyticsService.trackedEvents == [.goBackToDocumentsButton])
        #expect(didRunAction == true)
    }

    @Test("Each button tracks its own distinct event")
    func eachButtonTracksOwnEvent() throws {
        let sut = makeSUT(buttons: [goBackButton(), cancelButton()])

        let primary = try #require(sut.buttonViewModels.first)
        let secondary = try #require(sut.buttonViewModels.last)
        primary.action()
        secondary.action()

        #expect(mockAnalyticsService.trackedEvents == [.goBackToDocumentsButton, .cancel])
    }
}
