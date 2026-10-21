import DesignSystem
import SharingOrchestration

@MainActor
final class GetReadyToShareViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol
    ) {
        super.init(
            viewModel: GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator
            )
        )
    }
}
