import DesignSystem
import Foundation
import GDSAnalytics
import Logging
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
        isCancellable: Bool,
        analyticsService: AnalyticsService? = nil
    ) {
        self.orchestrator = orchestrator

        let loadingTitleKey = isCancellable ? "loadingGettingListOfDetails" : "loadingSharingYourDetails"
        let loadingTitle = GDSLocalisedString(stringKey: loadingTitleKey, bundle: .module)

        // Each screen maps to its own Firebase screen ID / taxonomy name.
        let screen: AnalyticsScreen = isCancellable ? .gettingListOfDetails : .sharingYourDetails

        let loadingText = GDSTextViewModel(
            title: loadingTitle,
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
                        analyticsService?.trackButtonEvent(
                            ButtonEvent(textKey: "cancel", bundle: .module)
                        )
                        Logger.log("Loading: Cancel tapped")
                        orchestrator.userDidTapCancel()
                    }
                )
            ]
        } else {
            self.rightBarButtons = nil
        }

        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: loadingTitle.value,
                screenClass: .modal,
                screenID: screen.id
            )
            Logger.log("Loading screen appeared")
        }
    }
}
