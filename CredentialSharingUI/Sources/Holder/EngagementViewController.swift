import DesignSystem
import Logging
import SharingOrchestration

@MainActor
final class EngagementViewController: GDSScreen {
    init(
        presentation: EngagementPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            viewModel: QRCodeViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        )
    }
}
