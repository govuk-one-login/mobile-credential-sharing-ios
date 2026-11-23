import CredentialSharingTestFixtures
import DesignSystem
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("UnfulfillableRequest Screen Tests")
struct UnfulfillableRequestTests {
    let mockOrchestrator = MockHolderOrchestrator()
    let mockAnalyticsService = MockSharingAnalyticsService()

    private func makeViewModel() throws -> UnfulfillableRequestViewModel {
        let sut = ResolutionViewController(
            presentation: .init(result: .unfulfillableRequest),
            orchestrator: mockOrchestrator,
            analyticsService: mockAnalyticsService
        )
        return try #require(sut.viewModel as? UnfulfillableRequestViewModel)
    }

    @Test("Body contains an icon, a header title and a combined body paragraph")
    func bodyComposition() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.body.count == 3)
        let icon = try #require(viewModel.body[0] as? GDSImageViewModel)
        #expect(icon.accessibilityIdentifier == "unfulfillable-request-icon")
        let title = try #require(viewModel.body[1] as? GDSTextViewModel)
        #expect(title.accessibilityTraits == .header)
        #expect(title.accessibilityIdentifier == "unfulfillable-request-title")
        let body = try #require(viewModel.body[2] as? GDSTextViewModel)
        #expect(body.accessibilityIdentifier == "unfulfillable-request-body")
    }

    @Test("Has no cancel/back affordance and no swipe-dismiss handler")
    func noCancelAffordance() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.rightBarButtonTitle == nil)
        #expect(viewModel.backButtonIsHidden == true)
        #expect(viewModel.didDismiss == nil)
    }

    @Test("Go back button finishes the journey and tracks a button event")
    func goBackButton() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.movableFooter.count == 1)
        let button = try #require(viewModel.movableFooter[0] as? GDSButtonViewModel)

        if case .action(let action) = button.buttonAction {
            action()
        } else {
            Issue.record("Expected a synchronous button action")
        }

        #expect(mockOrchestrator.userDidFinishCalled == true)
        #expect(mockAnalyticsService.trackedEvents == [.goBackToDocumentsButton])
    }

    @Test("didAppear tracks the screen with the low-level error description")
    func didAppearTracksErrorScreen() throws {
        let viewModel = try makeViewModel()
        #expect(mockAnalyticsService.trackedScreens.isEmpty)

        if case .action(let action) = viewModel.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous didAppear action")
        }

        #expect(mockAnalyticsService.trackedScreens == [.unfulfillableRequest])
        #expect(mockAnalyticsService.trackedErrorDescriptions == [UnfulfillableRequestViewModel.errorDescription])
    }
}
