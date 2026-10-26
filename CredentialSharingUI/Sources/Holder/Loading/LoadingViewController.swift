import DesignSystem
import Logging
import SharingLogging
import SharingOrchestration

@MainActor
final class LoadingViewController: GDSScreen {
    init(
        orchestrator: HolderOrchestratorProtocol,
        isCancellable: Bool,
        analyticsService: AnalyticsService? = nil
    ) {
        super.init(
            viewModel: LoadingViewModel(
                orchestrator: orchestrator,
                isCancellable: isCancellable,
                analyticsService: analyticsService
            )
        )
    }
}
