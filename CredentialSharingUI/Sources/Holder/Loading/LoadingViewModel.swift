import DesignSystem
import Foundation
import SharingLogging
import SharingOrchestration

@MainActor
struct LoadingViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .centred
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel] = []
    let footer: [any ContentViewModel] = []
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let rightBarButtons: [DesignSystem.NavigationBarButton]?
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil

    private let orchestrator: HolderOrchestratorProtocol

    init(
        orchestrator: HolderOrchestratorProtocol,
        isCancellable: Bool
    ) {
        self.orchestrator = orchestrator

        let loadingText = GDSTextViewModel(
            title: GDSLocalisedString(
                stringKey: isCancellable ? "loadingGettingListOfDetails" : "loadingSharingYourDetails",
                bundle: .module
            ),
            accessibilityIdentifier: "loading-text"
        )

        // The copy stays constant while loading, so all three stages show the
        // same text rather than the DesignSystem "still loading" defaults.
        let progressIndicator = GDSProgressIndicatorViewModel(
            title: loadingText,
            titleAfter5Seconds: loadingText,
            titleAfter10Seconds: loadingText,
            accessibilityIdentifier: "loading-progress-indicator"
        )

        self.body = [progressIndicator]

        // Cancel is only offered on the .processingEstablishment screen. Tapping
        // it defers to the orchestrator, which decides (based on session state)
        // whether to show the cancel-confirmation dialog.
        if isCancellable {
            self.rightBarButtons = [
                .button(
                    title: GDSLocalisedString(stringKey: "cancel", bundle: .module).value,
                    accessibilityIdentifier: "loading-cancel-button",
                    action: {
                        // TODO: Tracking
                        Logger.log("Loading: Cancel tapped")
                        orchestrator.userDidTapCancel()
                    }
                )
            ]
        } else {
            self.rightBarButtons = nil
        }

        self.didAppear = .action {
            // TODO: Tracking
            Logger.log("Loading screen appeared")
        }
    }
}
