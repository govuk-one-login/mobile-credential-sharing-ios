import DesignSystem
import Logging
import SharingLogging
import SharingOrchestration

@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil,
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
