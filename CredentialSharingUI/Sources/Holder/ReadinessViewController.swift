import DesignSystem
import Logging
import SharingOrchestration

@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        super.init(
            viewModel: GetReadyToShareViewModel(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService
                
            )
        )
    }
}

#if DEBUG
import CredentialSharingTestUtilities
import SwiftUI

@available(iOS 17, *)
#Preview {
    ReadinessViewController(
        presentation: ReadinessPresentation(
            missingPrerequisites: [],
            cancelRequiresConfirmation: false
        ),
        orchestrator: MockHolderOrchestrator()
    )
}
#endif
