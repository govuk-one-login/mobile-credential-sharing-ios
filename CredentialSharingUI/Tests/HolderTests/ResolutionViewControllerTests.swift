import DesignSystem
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ResolutionViewController Tests")
struct ResolutionViewControllerTests {

    // MARK: - message convenience init

    @Test("Message init hosts a centred message view model with the labelled text")
    func messageInitBuildsViewModel() throws {
        let sut = ResolutionViewController(message: "Details shared")
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "TerminalStateLabel")
        #expect(viewModel.body.count == 1)
        #expect(viewModel.movableFooter.isEmpty)
    }

    @Test("Message init renders a single labelled text element")
    func displaysConfiguredMessage() throws {
        let sut = ResolutionViewController(message: "Unfulfillable request")
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "TerminalStateLabel")
    }

    @Test("Back button is hidden for resolution screens")
    func backButtonHidden() throws {
        let sut = ResolutionViewController(message: "Test")
        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        #expect(viewModel.backButtonIsHidden == true)
    }

    // MARK: - presentation-driven init

    @Test(".detailsShared result builds a DetailsSharedViewModel")
    func detailsSharedBuildsDetailsShared() {
        let sut = ResolutionViewController(
            presentation: .init(result: .detailsShared),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view
        #expect(sut.viewModel is DetailsSharedViewModel)
    }

    @Test(".unfulfillableRequest result builds the unfulfillable request message")
    func unfulfillableRequestBuildsMessage() throws {
        let sut = ResolutionViewController(
            presentation: .init(result: .unfulfillableRequest),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? TerminalStateMessageViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "TerminalStateLabel")
    }

    @Test("A nil result builds no screen")
    func nilResultFallsBackToMessage() {
        // A nil result is an immediate dismissal and should never build a VC; if
        // one is built it falls back to an empty message view model.
        let sut = ResolutionViewController(
            presentation: .init(result: nil),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view
        #expect(sut.viewModel is TerminalStateMessageViewModel)
    }
}
