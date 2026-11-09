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

    init(message: String) {
        super.init(viewModel: TerminalStateMessageViewModel(message: message))
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
            return TerminalStateMessageViewModel(message: "Unfulfillable request")
        case .failed:
            Logger.log("ResolutionViewController built for a .failed result — not handled in this ticket", level: .error)
            return TerminalStateMessageViewModel(message: "")
        case nil:
            Logger.log("ResolutionViewController built for a nil result — no screen is expected here", level: .error)
            return TerminalStateMessageViewModel(message: "")
        }
    }
}
