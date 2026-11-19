import DesignSystem
import SafariServices
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
final class ConsentViewController: GDSScreen {
    private let presentation: ConsentPresentation
    private let orchestrator: HolderOrchestratorProtocol
    private let analyticsService: SharingAnalyticsService?

    init(presentation: ConsentPresentation,
         orchestrator: HolderOrchestratorProtocol,
         analyticsService: SharingAnalyticsService? = nil,
         onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService

        let consentActions = ConsentActions()

        super.init(
            viewModel: ConsentViewModel(
                presentation: presentation,
                onAgree: { orchestrator.userDidTapApprove() },
                onReadAboutPrivacyNotice: {
                    consentActions.showMoreAboutDVS()
                },
                onCancel: onCancel,
                analyticsService: analyticsService
            )
        )

        consentActions.controller = self
    }

    func handleReadAboutPrivacyNotice() {
        let moreAboutDVSScreen = GDSScreen(
            viewModel: MoreAboutDVSViewModel(
                presentation: presentation,
                analyticsService: analyticsService,
                onOpenPrivacyNotice: { [weak self] in
                    self?.presentPrivacyNotice()
                },
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
        )

        let modalNavigationController = UINavigationController(
            rootViewController: moreAboutDVSScreen
        )

        modalNavigationController.modalPresentationStyle = .pageSheet
        modalNavigationController.presentationController?.delegate = self

        if let sheet = modalNavigationController.sheetPresentationController {
            sheet.prefersGrabberVisible = true
        }

        present(modalNavigationController, animated: true)
    }

    /// Opens the privacy notice in-app, over the More about DVS screen, so the
    /// user stays in the sharing journey and returns to it on close.
    private func presentPrivacyNotice() {
        presentedViewController?
            .present(
                SFSafariViewController(url: presentation.privacyPolicyURL),
                animated: true
            )
    }
}

// MARK: - ConsentActions

@MainActor
private final class ConsentActions {
    weak var controller: ConsentViewController?

    func showMoreAboutDVS() {
        controller?.handleReadAboutPrivacyNotice()
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension ConsentViewController: UIAdaptivePresentationControllerDelegate {
    /// Called only when the More about DVS sheet is swiped down (not for the
    /// Close button, which tracks its own event), so each close is logged once.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        analyticsService?.trackEvent(.close)
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
