import Logging
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
protocol HolderContainerDelegate: AnyObject {
    func consentRetryAvailable()
}

@MainActor
protocol HolderContainerProtocol: AnyObject {
    var delegate: HolderContainerDelegate? { get set }
}

@MainActor
class HolderContainer: UIViewController, HolderContainerProtocol {
    static let activityIndicatorIdentifier = "HolderContainerActivityIndicator"
    var orchestrator: HolderOrchestratorProtocol
    let activityIndicator = UIActivityIndicatorView(style: .large)
    weak var delegate: HolderContainerDelegate?
    private let analyticsService: AnalyticsService?

    init(orchestrator: HolderOrchestratorProtocol, analyticsService: AnalyticsService? = nil) {
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService
        super.init(nibName: nil, bundle: nil)
        self.orchestrator.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityIdentifier = HolderContainer.activityIndicatorIdentifier
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor
                .constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor
                .constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        activityIndicator.startAnimating()
        orchestrator.startPresentation()
    }
}

extension HolderContainer: @MainActor HolderOrchestratorDelegate {
    /// Whether the "Details shared" screen is currently on top. Terminal screens
    /// share `TerminalStateViewController`, so it's identified by its view model.
    private var isShowingDetailsShared: Bool {
        guard let terminal = navigationController?.topViewController as? TerminalStateViewController else {
            return false
        }
        return terminal.viewModel is DetailsSharedViewModel
    }

    func orchestrator(didUpdateState state: HolderSessionState?) {
        guard let state = state else {
            showError(.generic("Something went wrong. Try again later."))
            return
        }
        switch state {
        case .notStarted,
             .readyToPresent,
             .processingResponse,
             .terminatingSession:
            // Transient states with no screen of their own.
            break
        case .preflight(let presentation):
            // `.readyToPresent` is handled by the transient no-op group above.
            showGetReadyToShare(for: presentation)
        case .presentingEngagement(let qrCode):
            showQRCode(qrCode)
        case .processingEstablishment:
            navigateTo(LoadingViewController())
        case .awaitingUserConsent(let presentation):
            showConsent(for: presentation)
        case .awaitingVerifierResolution:
            showDetailsShared(for: state)
        case .success(let reason):
            handleSuccess(reason, state: state)
        case .cancelled:
            dismiss()
        case .failed(let error):
            handleFailure(error)
        }
    }

    // MARK: - State handlers

    private func handleSuccess(_ reason: SuccessReason, state: HolderSessionState) {
        switch reason {
        case .responseSent:
            showDetailsShared(for: state)
        case .denialResponse:
            dismiss()
        case .emptyResponse:
            showUnfulfillableRequest(for: state)
        }
    }

    private func handleFailure(_ error: SessionError) {
        switch error {
        case .transportError:
            showError(error)
        case .peerTermination where isShowingDetailsShared:
            // Peer terminated while the details shared screen is visible — stay put.
            break
        default:
            Logger.log("Failed with error: \(error)", level: .error)
            showError(error)
        }
    }

    func orchestratorDidRequestCancelConfirmation() {
        Logger.log("Cancel confirmation dialog presented")
        let alert = UIAlertController(
            title: nil,
            message: "Are you sure you want to cancel?",
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            Logger.log("Cancel confirmation confirmed — cancelling session")
            self?.orchestrator.userDidConfirmCancel()
        }

        let dismissAction = UIAlertAction(title: "No", style: .cancel) { _ in
            Logger.log("Cancel confirmation dismissed — session remains active")
        }

        alert.addAction(confirmAction)
        alert.addAction(dismissAction)

        navigationController?.present(alert, animated: true)
    }

    // MARK: - Showing screens

    private func showGetReadyToShare(for presentation: ReadinessPresentation) {
        navigateTo(
            ReadinessViewController(
                presentation: presentation,
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        )
    }

    private func showConsent(for presentation: ConsentPresentation) {
        navigateTo(
            ConsentViewController(presentation: presentation, orchestrator: orchestrator, container: self)
        )
    }

    private func showQRCode(_ qrCode: UIImage?) {
        // TODO: DCMAW-18470 Refactor QRCodeVC to remove settings / other view states
        let qrCodeViewController = QRCodeViewController(qrCode: qrCode)
        qrCodeViewController.delegate = self
        qrCodeViewController.showQRCode()
        navigateTo(qrCodeViewController)
    }

    private func showDetailsShared(for state: HolderSessionState) {
        // The success flow can request this screen more than once
        // (awaitingVerifierResolution, then success(.responseSent)); only push it
        // the first time.
        guard !isShowingDetailsShared else { return }
        Logger.log("Navigating to details shared screen")
        navigateTo(makeTerminalScreen(for: state))
    }

    private func showUnfulfillableRequest(for state: HolderSessionState) {
        Logger.log("Navigating to unfulfillable request screen")
        navigateTo(makeTerminalScreen(for: state))
    }

    private func showError(_ error: SessionError) {
        navigateTo(ErrorViewController(error: error, analyticsService: analyticsService))
    }

    private func dismiss() {
        navigationController?.dismiss(animated: true)
    }

    // MARK: - Screen factories & queries

    /// Builds the shared terminal screen (`TerminalStateViewController`) for the
    /// given terminal state. The controller selects its own view model from the
    /// state, mirroring `ReadinessViewController`.
    private func makeTerminalScreen(for state: HolderSessionState) -> TerminalStateViewController {
        TerminalStateViewController(
            state: state,
            orchestrator: orchestrator,
            analyticsService: analyticsService
        )
    }

    private func navigateTo(_ view: UIViewController) {
        navigationController?.pushViewController(view, animated: false)
        activityIndicator.stopAnimating()
    }

    func orchestratorFailedRecoverably() {
        delegate?.consentRetryAvailable()
    }

    func orchestratorDidFinish() {
        Logger.log("Holder journey finished — dismissing")
        navigationController?.dismiss(animated: true)
    }
}

extension HolderContainer: @MainActor QRCodeViewControllerDelegate {
    func didTapCancel() {
        Logger.log("Tapped cancel")
        self.orchestrator.userDidTapCancel()
    }
    
    func didTapNavigateToSettings() {
        Logger.log("Tapped navigate to settings")
    }
}
