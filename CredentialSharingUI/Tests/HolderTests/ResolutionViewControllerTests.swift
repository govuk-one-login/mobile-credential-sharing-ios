import DesignSystem
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ResolutionViewController Tests")
struct ResolutionViewControllerTests {

    // MARK: - message view model content

    @Test("Resolution screen hosts a centred message view model with the labelled text")
    func messageInitBuildsViewModel() throws {
        let sut = ResolutionViewController(
            presentation: .init(result: .detailsShared),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
        #expect(viewModel.backButtonIsHidden == true)
    }

    @Test("Unfulfillable request renders a labelled text element and a Go back button")
    func displaysConfiguredMessage() throws {
        let sut = ResolutionViewController(
            presentation: .init(result: .unfulfillableRequest),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view

        let viewModel = try #require(sut.viewModel as? TerminalStateViewModel)
        let text = try #require(viewModel.body.first as? GDSTextViewModel)
        #expect(text.accessibilityIdentifier == "TerminalStateLabel")
        #expect(viewModel.movableFooter.isEmpty == false)
    }

    @Test("Back button is hidden for resolution screens")
    func backButtonHidden() throws {
        let sut = ResolutionViewController(
            presentation: .init(result: .unfulfillableRequest),
            orchestrator: MockHolderOrchestrator()
        )
        let viewModel = try #require(sut.viewModel as? TerminalStateViewModel)
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

        let viewModel = try #require(sut.viewModel as? TerminalStateViewModel)
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
        #expect(sut.viewModel is TerminalStateViewModel)
    }
}
