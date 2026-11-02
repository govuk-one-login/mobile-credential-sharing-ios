import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
final class ConsentViewController: GDSScreen {
    private let orchestrator: HolderOrchestratorProtocol

    init(presentation: ConsentPresentation,
         orchestrator: HolderOrchestratorProtocol,
         analyticsService: AnalyticsService? = nil
    ) {
        self.orchestrator = orchestrator
        // cancel/dismiss wiring lands in DCMAW-23709 and readAbout in DCMAW-23711
        super.init(
            viewModel: ConsentViewModel(
                presentation: presentation,
                onAgree: { orchestrator.userDidTapApprove() },
                onReadAbout: {},
                onCancel: {},
                analyticsService: analyticsService
            )
        )
    }
}

// MARK: - ConsentRetryDelegate

extension ConsentViewController: ConsentRetryDelegate {
    /// Buttons aren't disabled on tap (whilst "Busy"), so nothing to re-enable on retry.
    /// nav controller uses this so it can still wire as its retry delegate.
    func consentRetryAvailable() {}
}
