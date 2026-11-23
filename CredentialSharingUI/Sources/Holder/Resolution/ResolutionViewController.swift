import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
final class ResolutionViewController: GDSScreen {

    init(
        presentation: ResolutionPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil
    ) {
        super.init(
            viewModel: Self.makeViewModel(
                for: presentation.result,
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        )
    }

    /// Selects and builds the view model for a resolution result.
    private static func makeViewModel(
        for result: ResolutionResult?,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService?
    ) -> GDSScreenViewModel {
        switch result {
        case .detailsShared:
            return DetailsSharedViewModel(
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        case .unfulfillableRequest:
            return UnfulfillableRequestViewModel(
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        case .failed:
            // Failures are rendered by `HolderNavigationController` (generic error
            // screen or legacy `ErrorViewController`), never by this controller.
            Logger.log("ResolutionViewController built for a .failed result — unexpected, failures are routed elsewhere", level: .error)
            return ResolutionViewModel(
                orchestrator: orchestrator,
                message: ""
            )
        case nil:
            Logger.log("ResolutionViewController built for a nil result — no screen is expected here", level: .error)
            return ResolutionViewModel(
                orchestrator: orchestrator,
                message: ""
            )
        }
    }
}
