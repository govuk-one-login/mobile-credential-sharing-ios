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

    // MARK: - hosting an arbitrary terminal view model

    @Test("Can host any GDSScreenViewModel, e.g. DetailsSharedViewModel")
    func hostsProvidedViewModel() {
        let sut = TerminalStateViewController(
            viewModel: DetailsSharedViewModel(orchestrator: MockHolderOrchestrator())
        )
        _ = sut.view
        #expect(sut.viewModel is DetailsSharedViewModel)
    }

    @Test("A view model's footer bottom inset overrides the GDSScreen default")
    func appliesFooterBottomInset() throws {
        let sut = TerminalStateViewController(
            viewModel: DetailsSharedViewModel(orchestrator: MockHolderOrchestrator())
        )
        sut.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        sut.view.layoutIfNeeded()

        let footerStack = try #require(
            firstStackView(in: sut.view, identifier: "gds-screen-bottom-stack-view")
        )
        #expect(footerStack.directionalLayoutMargins.bottom == 0)
    }

    private func firstStackView(in root: UIView, identifier: String) -> UIStackView? {
        if root.accessibilityIdentifier == identifier, let stack = root as? UIStackView {
            return stack
        }
        for subview in root.subviews {
            if let match = firstStackView(in: subview, identifier: identifier) {
                return match
            }
        }
        return nil
    }
}
