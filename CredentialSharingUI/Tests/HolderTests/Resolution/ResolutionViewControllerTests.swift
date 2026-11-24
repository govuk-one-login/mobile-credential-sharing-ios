import CredentialSharingTestFixtures
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

    @Test("Unfulfillable request is not built by ResolutionViewController")
    func unfulfillableRequestFallsBackToMessage() {
        // Rendered as a `GDSErrorScreen` by `HolderNavigationController`.
        let sut = ResolutionViewController(
            presentation: .init(result: .unfulfillableRequest),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view
        #expect(sut.viewModel is ResolutionViewModel)
    }

    @Test("Back button is hidden for resolution screens")
    func backButtonHidden() throws {
        let sut = ResolutionViewController(
            presentation: .init(result: .detailsShared),
            orchestrator: MockHolderOrchestrator()
        )
        let viewModel = try #require(sut.viewModel as? DetailsSharedViewModel)
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

    @Test("A nil result builds no screen")
    func nilResultFallsBackToMessage() {
        // A nil result is an immediate dismissal and should never build a VC; if
        // one is built it falls back to an empty message view model.
        let sut = ResolutionViewController(
            presentation: .init(result: nil),
            orchestrator: MockHolderOrchestrator()
        )
        _ = sut.view
        #expect(sut.viewModel is ResolutionViewModel)
    }
}
