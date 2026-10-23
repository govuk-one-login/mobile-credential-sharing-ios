import DesignSystem
import SharingOrchestration

@MainActor
final class LoadingViewController: GDSScreen {
    init(
        orchestrator: HolderOrchestratorProtocol,
        isCancellable: Bool
    ) {
        super.init(
            viewModel: LoadingViewModel(
                orchestrator: orchestrator,
                isCancellable: isCancellable
            )
        )
    }
}
