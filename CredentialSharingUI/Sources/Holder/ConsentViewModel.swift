import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration

@MainActor
struct ConsentViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .top
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil

    static let agreeButtonIdentifier = "ConsentAgreeButton"
    static let cancelButtonIdentifier = "ConsentCancelButton"
    static let readAboutButtonIdentifier = "ConsentReadAboutButton"

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

        // MARK: Body

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: ConsentContent.title),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "ConsentTitle",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        let organisationSentence = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: content.organisationSentence),
            accessibilityIdentifier: "ConsentOrganisationSentence"
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
            // `.secondaryLeading` zeroes its own content insets, so without this
            // the button hugs the screen edge. Match the 16pt body-text margin.
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        let whatYoullShareHeading = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: ConsentContent.whatYoullShareHeading),
            titleFont: DesignSystem.Font.Base.title2Bold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "ConsentWhatYoullShareHeading",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        // MARK: - Param's card here
        // let card = ShareSummaryCardViewModel(content: content)
        let card = Self.makeCard(content: content) // temp

        self.body = [title, organisationSentence, readAboutButton, whatYoullShareHeading, card]

        // MARK: Footer Buttons

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
            verticalPadding: .vertical(DesignSystem.Spacing.small),
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        let cancelButton = GDSButtonViewModel(
            title: ConsentContent.cancelButtonTitle,
            style: .secondary,
            buttonAction: .action {
                analyticsService?.trackButtonEvent(
                    ButtonEvent(textKey: "agreeToShareCancelButtonAnalytics", bundle: .module)
                )
                onCancel()
            },
            accessibilityIdentifier: Self.cancelButtonIdentifier,
            verticalPadding: .vertical(DesignSystem.Spacing.small),
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        self.movableFooter = [agreeButton, cancelButton]

        // MARK: Analytics

        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: ConsentContent.title,
                screenClass: .uiController,
                screenID: AnalyticsScreen.consent.id
            )
        }
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
            accessibilityIdentifier: "ConsentShareSummaryCard"
        ) {
            items
        }
    }
}
