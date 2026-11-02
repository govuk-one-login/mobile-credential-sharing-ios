import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration

@MainActor
struct ConsentViewModel: GDSScreenViewModel, BaseViewModel {
    static let agreeButtonIdentifier = "consent-agree-button"
    static let cancelButtonIdentifier = "consent-cancel-button"
    static let readAboutButtonIdentifier = "consent-read-about-button"

    let screenStyle: GDSScreenStyle = .top
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil

    private let content: ConsentContent
    private let analyticsService: AnalyticsService?

    init(
        presentation: ConsentPresentation,
        onAgree: @escaping () -> Void,
        onReadAbout: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        analyticsService: AnalyticsService? = nil
    ) {
        let content = ConsentContent(presentation: presentation)
        self.content = content
        self.analyticsService = analyticsService
        self.body = Self.makeBody(content: content, onReadAbout: onReadAbout, analyticsService: analyticsService)
        self.movableFooter = Self.makeFooter(
            content: content,
            onAgree: onAgree,
            onCancel: onCancel,
            analyticsService: analyticsService
        )
        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: GDSLocalisedString(stringKey: "agreeToShareTitle", bundle: .module).value,
                screenClass: .uiController,
                screenID: AnalyticsScreen.consent.id
            )
        }
    }

    private static func makeBody(
        content: ConsentContent,
        onReadAbout: @escaping () -> Void,
        analyticsService: AnalyticsService?
    ) -> [any ContentViewModel] {
        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "agreeToShareTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "consent-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        let organisationSentence = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: content.organisationSentence),
            accessibilityIdentifier: "consent-organisation-sentence"
        )

        let readAboutButton = GDSButtonViewModel(
            title: content.readAboutButtonTitle,
            style: .secondaryLeading,
            buttonAction: .action {
                analyticsService?.trackButtonEvent(
                    ButtonEvent(textKey: "agreeToShareReadAboutButtonAnalytics", bundle: .module)
                )
                onReadAbout()
            },
            accessibilityIdentifier: Self.readAboutButtonIdentifier,
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        let whatYoullShareHeading = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "agreeToShareWhatYoullShareHeading", bundle: .module),
            titleFont: DesignSystem.Font.Base.title2Bold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "consent-what-youll-share-heading",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        // MARK: - Param's card here
        // let card = ShareSummaryCardViewModel(content: content)
        let card = Self.makeCard(content: content) // temp

        return [title, organisationSentence, readAboutButton, whatYoullShareHeading, card]
    }

    private static func makeFooter(
        content: ConsentContent,
        onAgree: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        analyticsService: AnalyticsService?
    ) -> [any ContentViewModel] {
        let agreeButton = GDSButtonViewModel(
            title: content.agreeButtonTitle,
            style: .primary.adjusting(
                cornerStyle: .fixed,
                cornerRadius: DesignSystem.CornerRadius.primaryButton
            ),
            buttonAction: .action {
                analyticsService?.trackButtonEvent(
                    ButtonEvent(textKey: "agreeToShareAgreeButtonAnalytics", bundle: .module)
                )
                onAgree()
            },
            accessibilityIdentifier: Self.agreeButtonIdentifier,
            verticalPadding: .vertical(DesignSystem.Spacing.default),
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        let cancelButton = GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "agreeToShareCancelButton", bundle: .module).value,
            style: .secondary,
            buttonAction: .action {
                analyticsService?.trackButtonEvent(
                    ButtonEvent(textKey: "agreeToShareCancelButtonAnalytics", bundle: .module)
                )
                onCancel()
            },
            accessibilityIdentifier: Self.cancelButtonIdentifier,
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        return [agreeButton, cancelButton]
    }

    /// temp card built from existing DesignSystem components to be replaced by Param's
    private static func makeCard(content: ConsentContent) -> GDSCardViewModel {
        var items: [any ContentViewModel] = [
            GDSTextViewModel(
                title: GDSLocalisedString(stringLiteral: content.summary),
                titleFont: DesignSystem.Font.Base.bodyBold
            )
        ]
        for section in content.sections {
            if let heading = section.heading {
                items.append(GDSTextViewModel(title: GDSLocalisedString(stringLiteral: heading)))
            }
            items.append(contentsOf: section.items.map {
                GDSTextViewModel(title: GDSLocalisedString(stringLiteral: $0))
            })
            if let footnote = section.footnote {
                items.append(GDSTextViewModel(title: GDSLocalisedString(stringLiteral: footnote)))
            }
        }
        return GDSCardViewModel(
            borderStyle: BorderStyle(width: 1, color: .systemGray4),
            accessibilityIdentifier: "consent-share-summary-card"
        ) {
            items
        }
    }
}
