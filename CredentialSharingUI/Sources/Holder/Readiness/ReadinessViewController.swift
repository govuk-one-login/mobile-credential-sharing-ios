import DesignSystem
import Logging
import SharingLogging
import SharingOrchestration

@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            viewModel: Self.viewModel(
                for: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        )
    }
    
    /// Maps a `ReadinessPresentation` to the view model for its state.
    static func viewModel(
        for presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) -> GDSScreenViewModel {
        switch presentation.missingPrerequisites.first {
        case .bluetooth(.statePoweredOff):
            return BluetoothPoweredOffViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        case .bluetooth(.authorizationNotDetermined):
            return GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        default:
            return GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        }
    }
}
