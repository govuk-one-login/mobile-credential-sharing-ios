import DesignSystem
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

    @Test("Screen style is centred")
    func screenStyleIsCentred() {
        let sut = TerminalStateViewController(message: "Test")
        #expect(sut.viewModel.screenStyle.verticalAlignment == .center)
    }

    // MARK: - hosting an arbitrary terminal view model

    @Test("Can host any GDSScreenViewModel, e.g. DetailsSharedViewModel")
    func hostsProvidedViewModel() {
        let sut = TerminalStateViewController(
            viewModel: DetailsSharedViewModel(orchestrator: MockHolderOrchestrator())
        )
        _ = sut.view
        #expect(sut.viewModel is DetailsSharedViewModel)
    }
}
