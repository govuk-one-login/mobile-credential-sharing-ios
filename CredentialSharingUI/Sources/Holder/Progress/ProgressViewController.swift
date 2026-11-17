import DesignSystem
import SharingLogging
import SharingOrchestration

@MainActor
final class ProgressViewController: GDSScreen {
    init(
        presentation: ProgressPresentation,
        analyticsService: SharingAnalyticsService? = nil,
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
