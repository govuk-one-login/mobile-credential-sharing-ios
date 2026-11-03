import DesignSystem
import Logging
import SharingLogging
import SharingOrchestration

@MainActor
final class ProgressViewController: GDSScreen {
    init(
        presentation: ProgressPresentation,
        analyticsService: AnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            viewModel: ProgressViewModel(
                presentation: presentation,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        )
    }
}
