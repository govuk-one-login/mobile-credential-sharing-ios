import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import UIKit

// MARK: - DetailsSharedViewModel

/// View model for the terminal "Details shared" screen shown once the Holder's
/// response has been sent.
///
/// Hosted by `TerminalStateViewController` (the shared terminal `GDSScreen`
/// base). Offers a single "Go back to documents" primary action. No Cancel bar
/// button is shown — `HolderContainerNavigation` treats terminal screens as
/// non-cancellable.

@MainActor
struct DetailsSharedViewModel: GDSScreenViewModel, BaseViewModel, TerminalFooterInsetProviding {
    let screenStyle: GDSScreenStyle = .centred
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil
    // Remove the GDSScreen default 16pt gap beneath the pinned footer button so
    // it no longer looks like it is floating. The button stays in the movable
    // footer (pinned, non-scrolling).
    let footerBottomInset: CGFloat? = 0

    private let orchestrator: HolderOrchestratorProtocol
    private let analyticsService: AnalyticsService?

    init(
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService

        self.body = Self.makeBody()
        self.movableFooter = [Self.makeGoBackButton(
            orchestrator: orchestrator,
            analyticsService: analyticsService
        )]
        self.didAppear = Self.makeDidAppearAction(analyticsService: analyticsService)
    }

    private static func makeBody() -> [any ContentViewModel] {
        let tickIcon = GDSImageViewModel(
            image: UIImage(systemName: "checkmark.circle") ?? UIImage(),
            imageColour: DesignSystem.Color.Icons.success,
            imageFixedHeight: 60,
            accessibilityIdentifier: "details-shared-tick-icon",
            verticalPadding: .vertical(0)
        )

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "detailsSharedTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            alignment: .center,
            accessibilityTraits: .header,
            accessibilityIdentifier: "details-shared-title",
            // 16pt gap above the title (between the icon and the title).
            verticalPadding: .top(DesignSystem.Spacing.default)
        )

        // One text view so VoiceOver reads both sentences as a single element.
        let bodyText = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "detailsSharedBody", bundle: .module),
            titleFont: DesignSystem.Font.Base.body,
            alignment: .center,
            accessibilityIdentifier: "details-shared-body",
            // 16pt gap above the body (between the title and the subtitle).
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        return [tickIcon, title, bodyText]
    }

    private static func makeGoBackButton(
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService?
    ) -> GDSButtonViewModel {
        GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "detailsSharedGoBackButton", bundle: .module).value,
            // Design specifies 16pt rounded corners rather than the default
            // capsule, so override the primary style's corner attributes.
            style: .primary.adjusting(
                cornerStyle: .fixed,
                cornerRadius: DesignSystem.CornerRadius.default
            ),
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
            // Horizontal padding only. The button stays pinned in the movable
            // footer; the footer's default 16pt bottom margin is tightened in
            // `TerminalStateViewController` so the button doesn't look like it
            // is floating.
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )
    }

    private static func makeDidAppearAction(
        analyticsService: AnalyticsService?
    ) -> DesignSystem.Action {
        .action {
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
