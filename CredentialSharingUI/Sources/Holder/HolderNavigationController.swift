import DesignSystem
import SafariServices
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
protocol ConsentRetryDelegate: AnyObject {
    func consentRetryAvailable()
}

@MainActor
class HolderNavigationController: UINavigationController {
    var orchestrator: HolderOrchestratorProtocol
    private var analyticsService: SharingAnalyticsService?
    private weak var retryDelegate: ConsentRetryDelegate?

    /// Confirmation requirement of the currently presented screen. Captured when
    /// each presentation is configured so cancel routing (tap or swipe-to-dismiss)
    /// can consult it without the caller supplying the flag. `nil` until the first
    /// screen is configured, in which case cancellation is a no-op.
    private var cancelRequiresConfirmation: Bool?

    /// True while the cancel confirmation alert is on screen.
    private var isShowingCancelConfirmation = false

    /// Most recent state received while the cancel confirmation alert was on
    /// screen. The orchestrator keeps running behind the alert, so rendering is
    /// deferred until the user answers it. Applied on "No"; on "Yes" it is only
    /// applied if the session has already ended and there is nothing left to cancel.
    private var deferredState: HolderSessionState??

    init(orchestrator: HolderOrchestratorProtocol, analyticsService: SharingAnalyticsService? = nil) {
        self.orchestrator = orchestrator
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
        self.analyticsService = analyticsService
        self.delegate = self
        self.isModalInPresentation = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.orchestrator.startTransaction()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Each time a new presentation is started, the presentationController delegate must be set
        self.presentationController?.delegate = self
    }
}

// MARK: - HolderOrchestratorDelegate
extension HolderNavigationController: @MainActor HolderOrchestratorDelegate {
    /// Whether the "Details shared" screen is currently on top. Resolution screens
    /// share `ResolutionViewController`, so it's identified by its view model.
    private var isShowingDetailsShared: Bool {
        guard let resolution = topViewController as? ResolutionViewController else {
            return false
        }
        return resolution.viewModel is DetailsSharedViewModel
    }

    func orchestrator(didUpdateState state: HolderSessionState?) {
        // Don't swap screens underneath the cancel confirmation alert; the user
        // is mid-decision. Hold the latest state and render it when they answer.
        if isShowingCancelConfirmation {
            deferredState = .some(state)
            return
        }
        render(state)
    }

    private func render(_ state: HolderSessionState?) {
        guard let state else {
            cancelRequiresConfirmation = nil
            navigateToErrorView(
                error: .generic("Something went wrong. Try again later.")
            )
            return
        }
        
        switch state {
        case .notStarted,
             .readyToPresent,
             .expired:
            break
        case .terminatingSession:
            cancelRequiresConfirmation = nil
        case .preflight(let presentation):
            renderGetReadyToShareUI(for: presentation)
        case .presentingEngagement(let presentation):
            renderQRCodeUI(with: presentation)
        case .processingEstablishment(let presentation):
            renderProgressUI(for: presentation)
        case .processingResponse(let presentation):
            renderProgressUI(for: presentation)
        case .awaitingUserConsent(let presentation):
            renderConsentUI(for: presentation)
        case .awaitingVerifierResolution:
            cancelRequiresConfirmation = nil
        case .success(let presentation):
            cancelRequiresConfirmation = nil
            showResolution(presentation)
        case .cancelled:
            cancelRequiresConfirmation = nil
            dismiss(animated: true)
        case .failed(let error):
            cancelRequiresConfirmation = nil
            handleFailure(error)
        }
    }

    /// Renders the resolution screen from the `.success` presentation. A `nil`
    /// result is an immediate dismissal; otherwise the matching screen is pushed.
    private func showResolution(_ presentation: ResolutionPresentation) {
        guard let result = presentation.result else {
            dismiss(animated: true)
            return
        }
        Logger.log("Navigating to resolution screen: \(String(describing: result))")
        navigateTo(
            ResolutionViewController(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        )
    }

    private func handleFailure(_ error: SessionError) {
        switch error {
        case .transportError:
            navigateToErrorView(error: error)
        case .peerTermination
            where isShowingDetailsShared:
            // Peer terminated while 'details shared' screen is visible — remain on current screen
            break
        default:
            Logger.log("Failed with error: \(error)", level: .error)
            navigateToErrorView(error: error)
        }
    }
    
    /// Routes a Cancel request (button tap or swipe-to-dismiss): screens whose
    /// presentation requires confirmation surface the confirmation alert; all
    /// others cancel immediately. Reads `cancelRequiresConfirmation`, captured
    /// when the current presentation was configured. A `nil` flag (no presentation
    /// configured yet) is a no-op.
    func handleCancel() {
        guard let cancelRequiresConfirmation else { return }

        if cancelRequiresConfirmation {
            presentCancelConfirmation()
        } else {
            orchestrator.userDidTapCancel()
        }
    }

    // TODO: DCMAW-23709 - Update the UI of the dialog here in DCMAW-23709
    func presentCancelConfirmation() {
        Logger.log("Cancel confirmation dialog presented")
        let alert = UIAlertController(
            title: nil,
            message: "Are you sure you want to cancel?",
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            Logger.log("Cancel confirmation confirmed — cancelling session")
            self?.cancelConfirmationConfirmed()
        }

        let dismissAction = UIAlertAction(title: "No", style: .cancel) { [weak self] _ in
            Logger.log("Cancel confirmation dismissed — session remains active")
            self?.cancelConfirmationDismissed()
        }

        alert.addAction(confirmAction)
        alert.addAction(dismissAction)

        isShowingCancelConfirmation = true
        deferredState = nil
        present(alert, animated: true)
    }

    /// "No": resume the flow by rendering whatever the orchestrator reached while
    /// the alert was up (a no-op if nothing changed — the current screen is correct).
    func cancelConfirmationDismissed() {
        isShowingCancelConfirmation = false
        guard let pending = deferredState else { return }
        deferredState = nil
        render(pending)
    }

    /// "Yes": cancel the session. If the session already ended while the alert was
    /// up there is nothing to cancel, so show where it ended up instead.
    func cancelConfirmationConfirmed() {
        isShowingCancelConfirmation = false
        let pending = deferredState
        deferredState = nil

        if let pending, hasSessionEnded(pending) {
            render(pending)
        } else {
            orchestrator.userDidTapCancel()
        }
    }

    private func hasSessionEnded(_ state: HolderSessionState?) -> Bool {
        switch state {
        case nil, .failed, .success, .cancelled, .expired:
            return true
        default:
            return false
        }
    }

    func orchestratorFailedRecoverably() {
        retryDelegate?.consentRetryAvailable()
    }

    func orchestratorDidFinish() {
        Logger.log("Holder journey finished — dismissing")
        dismiss(animated: true)
    }

    private func navigateToErrorView(error: SessionError) {
        let errorViewController = ErrorViewController(error: error, analyticsService: analyticsService)
        navigateTo(errorViewController)
    }

    private func renderGetReadyToShareUI(for presentation: ReadinessPresentation) {
        cancelRequiresConfirmation = presentation.cancelRequiresConfirmation
        navigateTo(
            ReadinessViewController(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService,
                onCancel: { [weak self] in
                    self?.handleCancel()
                }
            )
        )
    }

    private func renderProgressUI(for presentation: ProgressPresentation) {
        cancelRequiresConfirmation = presentation.cancelRequiresConfirmation
        navigateTo(
            ProgressViewController(
                presentation: presentation,
                analyticsService: analyticsService,
                onCancel: { [weak self] in
                    self?.handleCancel()
                }
            )
        )
    }

    private func renderConsentUI(for presentation: ConsentPresentation) {
        cancelRequiresConfirmation = presentation.cancelRequiresConfirmation
        let consentViewController = ConsentViewController(
            presentation: presentation,
            orchestrator: orchestrator,
            analyticsService: analyticsService,
            onReadAboutPrivacyNotice: { [weak self] in
                self?.handleReadAboutPrivacyNotice(for: presentation)
            },
            onCancel: { [weak self] in
                self?.handleCancel()
            }
        )
        retryDelegate = consentViewController
        navigateTo(consentViewController)
    }
    
    private func handleReadAboutPrivacyNotice(for presentation: ConsentPresentation) {
        let moreAboutDVSScreen = GDSScreen(
            viewModel: MoreAboutDVSViewModel(
                presentation: presentation,
                analyticsService: analyticsService,
                onOpenPrivacyNotice: { [weak self] in
                    self?.presentPrivacyNotice(presentation.privacyPolicyURL)
                },
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
        )
        let modalNavigationController = UINavigationController(rootViewController: moreAboutDVSScreen)
        modalNavigationController.isModalInPresentation = true
        present(modalNavigationController, animated: true)
    }

    /// Opens the privacy notice in-app so the user stays in the sharing journey
    /// and returns to the More about DVS screen when they close it.
    private func presentPrivacyNotice(_ url: URL) {
        let safariViewController = SFSafariViewController(url: url)
        (presentedViewController ?? self).present(safariViewController, animated: false)
    }

    private func renderQRCodeUI(
        with engagementPresentation: EngagementPresentation
    ) {
        // On refresh the top view controller is already a QR screen — update it in place
        // rather than pushing a new one, so the engagement QR can be refreshed on expiry
        // without growing the navigation stack or losing focus/scroll position.
        cancelRequiresConfirmation = engagementPresentation.cancelRequiresConfirmation
        do {
            if let existing = topViewController as? EngagementViewController {
                try existing.refresh(with: engagementPresentation)
            } else {
                let controller = try EngagementViewController(
                    presentation: engagementPresentation,
                    orchestrator: orchestrator,
                    analyticsService: analyticsService,
                    onCancel: { [weak self] in
                        self?.handleCancel()
                    }
                )
                navigateTo(controller)
            }
        } catch {
            // A QR we cannot render is unrecoverable — terminate the session for the
            // generation failure rather than present/keep a blank QR.
            Logger.log("QR code generation failed — terminating session", level: .error)
            orchestrator.qrCodeGenerationDidFail()
        }
    }

    private func navigateTo(_ viewController: UIViewController) {
        setViewControllers([viewController], animated: false)
    }
}

// MARK: - UINavigationControllerDelegate
extension HolderNavigationController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        
        // TODO: DCMAW-23709 Remove all logic from here down once all cancel buttons are implemented independently across UI screens

        // Only the legacy error screen is swipe-to-dismissable; every other
        // screen stays modal.
        isModalInPresentation = !(viewController is ErrorViewController)

        // GDS screens configure their own Cancel bar button.
        if viewController is GDSScreen { return }

        // navigateTo replaces the stack with a single VC, so the shown VC is
        // always the root; the legacy cancel-button setup below is retained.
        guard viewController !== viewControllers.first else { return }

        // Legacy UIKit screens still rely on the container provided cancel button below.
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        viewController.navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        viewController.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "CancelButton"
    }

    // TODO: DCMAW-23709 Remove when all UI implemented
    @objc private func cancelButtonTapped() {
        handleCancel()
    }
    
    func didFailToGenerateQRCode() {
            Logger.log("Failed to generate QR code", level: .error)
            orchestrator.qrCodeGenerationDidFail()
        }
}

// MARK: - Presentation Controller Delegate
extension HolderNavigationController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // A blocked swipe on a GDS screen is a no-op; cancel only via its button.
        guard !(topViewController is GDSScreen) else { return }
        handleCancel()
    }
}
