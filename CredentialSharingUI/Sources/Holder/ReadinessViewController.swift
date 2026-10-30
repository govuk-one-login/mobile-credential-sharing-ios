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
            viewModel: GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: onCancel
            )
        )
    }
}

#if DEBUG
import CredentialSharingTestFixtures
import SwiftUI

@available(iOS 17, *)
#Preview {
    ReadinessViewController(
        presentation: ReadinessPresentation(
            missingPrerequisites: [],
            cancelRequiresConfirmation: false
        ),
        orchestrator: MockHolderOrchestrator(),
        onCancel: {
            // No-op: previews are static and have no cancel flow to drive.
        }
    )
}
#endif
