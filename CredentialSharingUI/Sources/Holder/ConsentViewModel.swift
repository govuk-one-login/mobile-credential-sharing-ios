import DesignSystem
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
    private let analyticsService: SharingAnalyticsService?

    init(
        presentation: ConsentPresentation,
        onAgree: @escaping () -> Void,
        onReadAbout: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        analyticsService: SharingAnalyticsService? = nil
    ) {
        let content = ConsentContent(presentation: presentation)
        self.content = content
        self.analyticsService = analyticsService
        self.body = Self.makeBody(
            presentation: presentation,
            content: content,
            onReadAbout: onReadAbout,
            analyticsService: analyticsService
        )
        self.movableFooter = Self.makeFooter(
            content: content,
            onAgree: onAgree,
            onCancel: onCancel,
            analyticsService: analyticsService
        )
        self.didAppear = .action {
            analyticsService?.trackScreen(.consent)
        }
    }

    private static func makeBody(
        presentation: ConsentPresentation,
        content: ConsentContent,
        onReadAbout: @escaping () -> Void,
        analyticsService: SharingAnalyticsService?
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
                analyticsService?.trackEvent(.consentReadAboutButton)
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

        // Attributes card from main's AttributesCardViewModel (DCMAW-23849).
        let card = AttributesCardViewModel(presentation: presentation).card

        return [title, organisationSentence, readAboutButton, whatYoullShareHeading, card]
    }

    private static func makeFooter(
        content: ConsentContent,
        onAgree: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        analyticsService: SharingAnalyticsService?
    ) -> [any ContentViewModel] {
        let agreeButton = GDSButtonViewModel(
            title: content.agreeButtonTitle,
            style: .primary,
            buttonAction: .action {
                analyticsService?.trackEvent(.consentAgreeButton)
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
                analyticsService?.trackEvent(.consentCancelButton)
                onCancel()
            },
            accessibilityIdentifier: Self.cancelButtonIdentifier,
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        return [agreeButton, cancelButton]
    }
}
