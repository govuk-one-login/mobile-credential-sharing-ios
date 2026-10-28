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
        weak var consentScreen: GDSScreen?

        // cancel/dismiss wiring lands in DCMAW-23709
        super.init(
            viewModel: ConsentViewModel(
                presentation: presentation,
                onAgree: { orchestrator.userDidTapApprove() },
                onReadAbout: {
                    let moreAboutScreen = GDSScreen(
                        viewModel: MoreAboutDVSViewModel(
                            presentation: presentation,
                            orchestrator: orchestrator,
                            analyticsService: analyticsService,
                            onClose: {
                                consentScreen?.navigationController?.popViewController(animated: true)
                            }
                        )
                    )
                    consentScreen?.navigationController?.pushViewController(moreAboutScreen, animated: true)
                },
                onCancel: {},
                analyticsService: analyticsService
            )
        )
        consentScreen = self
    }
}

// MARK: - ConsentRetryDelegate

extension ConsentViewController: ConsentRetryDelegate {
    /// Buttons aren't disabled on tap (whilst "Busy"), so nothing to re-enable on retry.
    /// nav controller uses this so it can still wire as its retry delegate.
    func consentRetryAvailable() {
        // Intentionally empty: no buttons to re-enable on retry.
    }
}
