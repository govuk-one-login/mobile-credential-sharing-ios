import DesignSystem
import Logging
import SharingOrchestration

@MainActor
final class PrivacyPolicyViewController: GDSScreen {
    init(
        presentation: ConsentPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        super.init(
            viewModel: MoreAboutDVSViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService
                
            )
        )
    }
}
