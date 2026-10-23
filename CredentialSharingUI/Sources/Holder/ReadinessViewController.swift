import DesignSystem
import Logging
import SharingOrchestration
import SharingLogging

@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            viewModel: GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        )
    }
}
