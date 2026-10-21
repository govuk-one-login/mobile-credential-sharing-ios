import DesignSystem
import SharingOrchestration

@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol
    ) {
        super.init(
            viewModel: ReadinessViewModel(
                presentation: presentation,
                orchestrator: orchestrator
            )
        )
    }
}
