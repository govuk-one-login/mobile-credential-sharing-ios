import DesignSystem
import GDSAnalytics
import SharingLogging
import SharingOrchestration

// MARK: ReadinessViewController

@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        super.init(
            viewModel: GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        )
    }
}
