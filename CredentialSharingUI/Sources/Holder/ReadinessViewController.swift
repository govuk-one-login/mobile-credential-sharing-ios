import DesignSystem
import SharingOrchestration
import SharingPrerequisiteGate

/// Single view controller for every `preflight` / missing-prerequisite state.
///
/// The view controller stays mounted across preflight states; only the view
/// model is swapped to match the current `ReadinessPresentation`.
@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol
    ) {
        super.init(
            viewModel: ReadinessViewController.viewModel(
                for: presentation,
                orchestrator: orchestrator
            )
        )
    }

    /// Maps a `ReadinessPresentation` to the view model for its state.
    static func viewModel(
        for presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol
    ) -> GDSScreenViewModel {
        switch presentation.missingPrerequisites.first {
        case .bluetooth(.statePoweredOff):
            return TurnOnBluetoothViewModel(orchestrator: orchestrator)
        case .bluetooth(.authorizationNotDetermined):
            return GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator
            )
        default:
            return GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator
            )
        }
    }
}
