import GDSCommon
import SharingLogging
import SharingOrchestration
import UIKit

// MARK: - Failure routing
extension HolderNavigationController {
    /// Whether the "Details shared" screen is currently on top. Resolution screens
    /// share `ResolutionViewController`, so it's identified by its view model.
    private var isShowingDetailsShared: Bool {
        guard let resolution = topViewController as? ResolutionViewController else {
            return false
        }
        return resolution.viewModel is DetailsSharedViewModel
    }

    /// Renders a `.failed` presentation by switching on its `FailureCategory`.
    /// `.legacy` failures keep their existing `ErrorViewController` screen.
    func showFailure(_ presentation: ResolutionPresentation) {
        guard case .failed(let category, let errorDescription)? = presentation.result else {
            Logger.log("Failed state carried no failure result", level: .error)
            navigateToErrorView(error: .generic("Something went wrong. Try again later."))
            return
        }

        switch category {
        case .legacy(let error):
            handleFailure(error)
        case .generic:
            Logger.log("Failed with generic error: \(errorDescription)", level: .error)
            showGenericError(errorDescription: errorDescription)
        case .readerAuthentication:
            Logger.log("Failed with ReaderAuth error: \(errorDescription)", level: .error)
            showReaderAuthError(errorDescription: errorDescription)
        case .connectionInterrupted,
             .requestCannotBeUsed,
             .credentialUnavailable,
             .secureSharingCouldNotComplete,
             .unexpectedProblem:
            // TODO: DCMAW-24162 These categories are unused until their own tickets
            // land. Fall back to the generic screen.
            Logger.log("Failed with unmapped category \(category): \(errorDescription)", level: .error)
            showGenericError(errorDescription: errorDescription)
        }
    }

    /// Shows the legacy `ErrorViewController` for an error.
    func navigateToErrorView(error: SessionError) {
        let errorViewController = ErrorViewController(error: error, analyticsService: analyticsService)
        navigateTo(errorViewController)
    }

    private func showGenericError(errorDescription: String) {
        navigateTo(
            GDSErrorScreen.resolutionFailure(
                viewModel: ResolutionFailureViewModel.genericError(
                    errorDescription: errorDescription,
                    orchestrator: orchestrator,
                    analyticsService: analyticsService
                )
            )
        )
    }

    private func showReaderAuthError(errorDescription: String) {
        navigateTo(
            GDSErrorScreen.resolutionFailure(
                viewModel: ResolutionFailureViewModel.readerAuthError(
                    errorDescription: errorDescription,
                    orchestrator: orchestrator,
                    analyticsService: analyticsService
                )
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
}
