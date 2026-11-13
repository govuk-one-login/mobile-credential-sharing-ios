import DesignSystem
import Foundation
import SharingLogging
import SharingOrchestration

@MainActor
struct ProgressViewModel: GDSScreenViewModel, BaseViewModel {
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

    private let presentation: ProgressPresentation
    private let onCancel: () -> Void

    init(
        presentation: ProgressPresentation,
        analyticsService: SharingAnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onCancel = onCancel

        let progressTitle = GDSLocalisedString(stringKey: presentation.phase.analyticsScreen.titleKey, bundle: .module)

        let progressText = GDSTextViewModel(
            title: progressTitle,
            alignment: .center,
            accessibilityIdentifier: "progress-text"
        )

        // The copy stays constant while loading, so all three stages show the
        // same text rather than the DesignSystem "still loading" defaults.
        let progressIndicator = GDSProgressIndicatorViewModel(
            title: progressText,
            titleAfter5Seconds: progressText,
            titleAfter10Seconds: progressText,
            accessibilityIdentifier: "progress-progress-indicator"
        )

        self.body = [progressIndicator]

        // A Cancel control is offered only when the presentation specifies a
        // cancellation status. Tapping defers to `onCancel`, which routes through
        // the navigation controller's `handleCancel` to decide whether a
        // confirmation dialog is required.
        if presentation.cancelRequiresConfirmation != nil {
            self.rightBarButtons = [
                .button(
                    title: GDSLocalisedString(stringKey: "cancel", bundle: .module).value,
                    accessibilityIdentifier: "right-bar-button",
                    action: {
                        analyticsService?.trackEvent(.cancel)
                        Logger.log("Progress: Cancel tapped")
                        onCancel()
                    }
                )
            ]
        } else {
            self.rightBarButtons = nil
        }

        self.didAppear = .action {
            analyticsService?.trackScreen(presentation.phase.analyticsScreen)
            Logger.log("Progress screen appeared")
        }
    }
}

private extension ProgressPresentation.ProgressPhase {
    var analyticsScreen: SharingScreen {
        switch self {
        case .processingRequest:
            return .gettingListOfDetails
        case .sendingResponse:
            return .sharingYourDetails
        }
    }
}
