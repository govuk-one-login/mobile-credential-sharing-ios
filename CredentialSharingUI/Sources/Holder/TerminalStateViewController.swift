import DesignSystem
import Logging
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
final class TerminalStateViewController: GDSScreen {
    /// Accessibility identifier `GDSScreen` assigns to its movable-footer stack.
    private static let footerStackIdentifier = "gds-screen-bottom-stack-view"

    init(
        state: HolderSessionState,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        super.init(
            viewModel: Self.makeViewModel(
                for: state,
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        )
    }

    init(message: String) {
        super.init(viewModel: TerminalStateMessageViewModel(message: message))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    private func firstSubview(
        of root: UIView,
        withAccessibilityIdentifier identifier: String
    ) -> UIView? {
        if root.accessibilityIdentifier == identifier { return root }
        for subview in root.subviews {
            if let match = firstSubview(of: subview, withAccessibilityIdentifier: identifier) {
                return match
            }
        }
        return nil
    }

    /// Selects and builds the terminal view model for a given session state.
    private static func makeViewModel(
        for state: HolderSessionState,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService?
    ) -> GDSScreenViewModel {
        switch state {
        case .awaitingVerifierResolution,
             .success(reason: .responseSent):
            return DetailsSharedViewModel(
                orchestrator: orchestrator,
                analyticsService: analyticsService
            )
        case .success(reason: .emptyResponse):
            return TerminalStateMessageViewModel(message: "Unfulfillable request")
        default:
            Logger.log("TerminalStateViewController built for non-terminal state: \(String(describing: state))", level: .error)
            return TerminalStateMessageViewModel(message: "")
        }
    }
}
