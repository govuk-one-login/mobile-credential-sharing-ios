import DesignSystem
import SharingOrchestration

@MainActor
final class EngagementViewController: GDSScreen {
    init(
        presentation: EngagementPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil,
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
