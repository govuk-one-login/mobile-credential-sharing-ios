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

    private let analyticsService: SharingAnalyticsService?

    init(
        presentation: ConsentPresentation,
        onAgree: @escaping () -> Void,
        onReadAbout: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        analyticsService: SharingAnalyticsService? = nil
    ) {
        self.analyticsService = analyticsService
        let attributesCard = AttributesCardViewModel(presentation: presentation)
        self.body = Self.makeBody(
            presentation: presentation,
            attributesCard: attributesCard,
            onReadAbout: onReadAbout,
            analyticsService: analyticsService
        )
        self.movableFooter = Self.makeFooter(
            attributesCard: attributesCard,
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
        attributesCard: AttributesCardViewModel,
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
            title: GDSLocalisedString(stringLiteral: Self.organisationSentence(for: presentation)),
            accessibilityIdentifier: "consent-organisation-sentence"
        )

        let readAboutButton = GDSButtonViewModel(
            title: Self.readAboutButtonTitle(for: presentation),
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
            verticalPadding: .vertical(DesignSystem.Spacing.small)
        )

        let card = attributesCard.card

        return [title, organisationSentence, readAboutButton, whatYoullShareHeading, card]
    }

    private static func makeFooter(
        attributesCard: AttributesCardViewModel,
        onAgree: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        analyticsService: SharingAnalyticsService?
    ) -> [any ContentViewModel] {
        let agreeButton = GDSButtonViewModel(
            title: Self.agreeButtonTitle(count: attributesCard.sharedCount),
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

    // MARK: - Copy

    /// "The person doing the check is using an approved app powered by {DVS}."
    /// Uses the normalised DVS name so a trailing full stop isn't doubled.
    static func organisationSentence(for presentation: ConsentPresentation) -> String {
        localized("agreeToShareDVSSentence", presentation.normalisedDvsName)
    }

    /// "Read about {DVS} and their privacy notice" — keeps the raw DVS name (mid-sentence).
    static func readAboutButtonTitle(for presentation: ConsentPresentation) -> String {
        localized("agreeToShareReadAboutButton", presentation.dvsName)
    }

    /// "Agree and share {count} {detail(s)}". The count comes from
    /// `AttributesCardViewModel.sharedCount` so the button and card agree.
    static func agreeButtonTitle(count: Int) -> String {
        localized("agreeToShareAgreeButton", count, detailsWord(for: count))
    }

    private static func detailsWord(for count: Int) -> String {
        count == 1
            ? localized("agreeToShareDetailSingular")
            : localized("agreeToShareDetailPlural")
    }

    private static func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key), bundle: .module)
        return String(format: format, locale: .current, arguments: arguments)
    }
}
