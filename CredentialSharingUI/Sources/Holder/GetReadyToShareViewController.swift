import DesignSystem
import Logging
import SharingOrchestration

@MainActor
final class GetReadyToShareViewController: GDSScreen {
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
