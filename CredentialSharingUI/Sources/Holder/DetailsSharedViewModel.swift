import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import UIKit

// MARK: -  DetailsSharedViewModel

/// View model for the terminal "Details shared" screen shown once the Holder's
/// response has been sent.
///
/// Hosted by `TerminalStateViewController` (the shared terminal `GDSScreen`
/// base). Offers a single "Go back to documents" primary action. No Cancel bar
/// button is shown — `HolderContainerNavigation` treats terminal screens as
/// non-cancellable.

@MainActor
struct DetailsSharedViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .centred
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil

    private let orchestrator: HolderOrchestratorProtocol
    private let analyticsService: AnalyticsService?

    init(
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService

        let tickIcon = GDSImageViewModel(
            image: UIImage(systemName: "checkmark.circle") ?? UIImage(),
            imageColour: DesignSystem.Color.Icons.success,
            imageFixedHeight: 60,
            accessibilityIdentifier: "details-shared-tick-icon",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "detailsSharedTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            alignment: .center,
            accessibilityTraits: .header,
            accessibilityIdentifier: "details-shared-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        // One text view so VoiceOver reads both sentences as a single element.
        let bodyText = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "detailsSharedBody", bundle: .module),
            alignment: .center,
            accessibilityIdentifier: "details-shared-body"
        )

        self.body = [tickIcon, title, bodyText]

        let goBackButton = GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "detailsSharedGoBackButton", bundle: .module).value,
            style: .primary,
            buttonAction: .action {
                analyticsService?.trackButtonEvent(
                    ButtonEvent(
                        textKey: "detailsSharedGoBackButton",
                        bundle: .module
                    )
                )
                Logger.log("Details Shared: Go back to documents tapped")
                orchestrator.userDidFinish()
            },
            accessibilityIdentifier: "details-shared-go-back-button",

            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        self.movableFooter = [goBackButton]

        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: GDSLocalisedString(stringKey: "detailsSharedTitle", bundle: .module).value,
                screenClass: .modal,
                screenID: AnalyticsScreen.detailsShared.id
            )
            Logger.log("Details Shared screen appeared")
        }
    }
}
