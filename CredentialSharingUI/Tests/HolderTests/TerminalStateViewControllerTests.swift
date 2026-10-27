import DesignSystem
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("TerminalStateViewController Tests")
struct TerminalStateViewControllerTests {

    // MARK: - message convenience init

    @Test("Message init hosts a centred message view model with the labelled text")
    func messageInitBuildsViewModel() throws {
        let sut = TerminalStateViewController(message: "Details shared")
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "TerminalStateLabel")
        #expect(viewModel.body.count == 1)
        #expect(viewModel.movableFooter.isEmpty)
    }

    @Test("Message init renders a single labelled text element")
    func displaysConfiguredMessage() throws {
        let sut = TerminalStateViewController(message: "Unfulfillable request")
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "TerminalStateLabel")
    }

    @Test("Back button is hidden for terminal screens")
    func backButtonHidden() throws {
        let sut = TerminalStateViewController(message: "Test")
        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        #expect(viewModel.backButtonIsHidden == true)
    }

    // MARK: - state-driven init

    @Test(".awaitingVerifierResolution builds a DetailsSharedViewModel")
    func awaitingVerifierResolutionBuildsDetailsShared() {
        let sut = TerminalStateViewController(
            state: .awaitingVerifierResolution,
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view
        #expect(sut.viewModel is DetailsSharedViewModel)
    }

    @Test(".success(.responseSent) builds a DetailsSharedViewModel")
    func responseSentBuildsDetailsShared() {
        let sut = TerminalStateViewController(
            state: .success(reason: .responseSent),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view
        #expect(sut.viewModel is DetailsSharedViewModel)
    }

    @Test(".success(.emptyResponse) builds the unfulfillable request message")
    func emptyResponseBuildsMessage() throws {
        let sut = TerminalStateViewController(
            state: .success(reason: .emptyResponse),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "TerminalStateLabel")
    }

    @Test("A non-terminal state falls back to a message view model")
    func nonTerminalStateFallsBackToMessage() {
        let sut = TerminalStateViewController(
            state: .cancelled,
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view
        #expect(sut.viewModel is TerminalStateMessageViewModel)
    }
}
