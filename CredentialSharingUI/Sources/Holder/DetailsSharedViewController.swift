import DesignSystem
import GDSAnalytics
import SharingLogging
import SharingOrchestration
import UIKit

// MARK: DetailsSharedViewController

/// Terminal "Details shared" screen shown once the Holder's response has been
/// sent.
///
/// Offers a single "Go back to documents" primary action. The Cancel bar button
/// is present and does not require a confirmation dialogue.
@MainActor
final class DetailsSharedViewController: GDSScreen {
    init(orchestrator: HolderOrchestratorProtocol) {
        super.init(
            viewModel: DetailsSharedViewModel(orchestrator: orchestrator)
        )
    }
}

// MARK: DetailsSharedViewModel

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

    init(orchestrator: HolderOrchestratorProtocol) {
        self.orchestrator = orchestrator

        let tickIcon = GDSImageViewModel(
            image: UIImage(systemName: "checkmark.circle.fill") ?? UIImage(),
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
                // Analytics event to be dispatched once analytics is wired up.
                _ = ButtonEvent(
                    textKey: "detailsSharedGoBackButton",
                    bundle: .module
                )
                Logger.log("Details Shared: Go back to documents tapped")
                // Ends the connection and dismisses the journey.
                orchestrator.userDidTapCancel()
            },
            accessibilityIdentifier: "details-shared-go-back-button",
            verticalPadding: .vertical(DesignSystem.Spacing.default),
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        self.movableFooter = [goBackButton]

        self.didAppear = .action {
            // Screen view to be dispatched once analytics is wired up.
            _ = ScreenView(
                id: AnalyticsScreen.detailsShared.id,
                screen: AnalyticsScreen.detailsShared,
                titleKey: "detailsSharedTitle",
                bundle: .module
            )
            Logger.log("Details Shared screen appeared")
        }
    }
}
