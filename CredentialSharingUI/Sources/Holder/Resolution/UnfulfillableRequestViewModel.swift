import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

// MARK: - UnfulfillableRequestViewModel

/// View model for the terminal "Details requested not available" error screen,
/// shown when the verifier's request cannot be fulfilled (a DocType other than
/// the UK driving licence, or no requested data elements present on it).
///
/// Hosted by `ResolutionViewController`. Offers a single "Go back to documents"
/// primary action. There is no Cancel bar button, and no cancel confirmation is
/// required on this screen (`cancelRequiresConfirmation == false` semantics).
@MainActor
struct UnfulfillableRequestViewModel: GDSScreenViewModel, BaseViewModel {
    /// Low-level reason logged as `error_reason` on the screen view event.
    static let errorDescription = "The request cannot be fulfilled: no supported document type or data elements were requested"

    let screenStyle: GDSScreenStyle = .centred
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil

    init(
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil
    ) {
        self.body = Self.makeBody()
        self.movableFooter = [Self.makeGoBackButton(
            orchestrator: orchestrator,
            analyticsService: analyticsService
        )]
        self.didAppear = .action {
            analyticsService?.trackScreen(.unfulfillableRequest, with: Self.errorDescription)
            Logger.log("Unfulfillable Request screen appeared")
        }
    }

    private static func makeBody() -> [any ContentViewModel] {
        let scaledIconFont = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 64, weight: .regular)
        )
        let warningImage = UIImage(
            systemName: "exclamationmark.circle",
            withConfiguration: UIImage.SymbolConfiguration(font: scaledIconFont)
        ) ?? UIImage()

        // Decorative: the title already conveys the error to VoiceOver.
        let warningIcon = GDSImageViewModel(
            image: warningImage,
            imageColour: DesignSystem.Color.Icons.default,
            contentMode: .center,
            accessibilityIdentifier: "unfulfillable-request-icon",
            verticalPadding: .vertical(0)
        )

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "unfulfillableRequestTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            alignment: .center,
            accessibilityTraits: .header,
            accessibilityIdentifier: "unfulfillable-request-title",
            verticalPadding: .top(DesignSystem.Spacing.default)
        )

        // One text view so VoiceOver reads both paragraphs as a single element.
        let bodyText = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "unfulfillableRequestBody", bundle: .module),
            titleFont: DesignSystem.Font.Base.body,
            alignment: .center,
            accessibilityIdentifier: "unfulfillable-request-body",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        return [warningIcon, title, bodyText]
    }

    private static func makeGoBackButton(
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService?
    ) -> GDSButtonViewModel {
        GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "goBackToDocumentsButton", bundle: .module).value,
            style: .primary,
            buttonAction: .action {
                analyticsService?.trackEvent(.goBackToDocumentsButton)
                Logger.log("Unfulfillable Request: Go back to documents tapped")
                orchestrator.userDidFinish()
            },
            accessibilityIdentifier: "unfulfillable-request-go-back-button",
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )
    }
}
