import DesignSystem
import Foundation
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
struct MoreAboutDVSViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .top
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel] = []
    let footer: [any ContentViewModel] = []
    let rightBarButtons: [DesignSystem.NavigationBarButton]?
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil

    let analyticsService: SharingAnalyticsService?

    init(
        presentation: ConsentPresentation,
        analyticsService: SharingAnalyticsService? = nil,
        onClose: @escaping () -> Void = {}
    ) {
        self.analyticsService = analyticsService

        let dvsName = presentation.dvsName

        self.rightBarButtons = [
            Self.closeButton(analyticsService: analyticsService, onClose: onClose)
        ]

        self.body = [
            Self.titleViewModel(dvsName: dvsName),
            Self.introViewModel(dvsName: dvsName),
            Self.requiredCertificationsList(dvsName: dvsName),
            Self.privacyPolicyTitle(dvsName: dvsName),
            Self.privacyPolicyList(dvsName: dvsName),
            Self.privacyNoticeLink(
                dvsName: dvsName,
                privacyPolicyURL: presentation.privacyPolicyURL,
                analyticsService: analyticsService
            )
        ]

        self.didAppear = .action {
            analyticsService?.trackScreen(.moreAboutDVS)
        }
    }

    // MARK: - Bar buttons

    private static func closeButton(
        analyticsService: SharingAnalyticsService?,
        onClose: @escaping () -> Void
    ) -> DesignSystem.NavigationBarButton {
        .button(
            title: GDSLocalisedString(stringKey: "close", bundle: .module).value,
            accessibilityIdentifier: "more-about-dvs-close-button",
            action: {
                analyticsService?.trackEvent(.close)
                onClose()
            }
        )
    }

    // MARK: - Body content

    private static func titleViewModel(dvsName: String) -> GDSTextViewModel {
        GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "moreAboutDVSTitle", dvsName, bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "more-about-dvs-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )
    }

    private static func introViewModel(dvsName: String) -> GDSTextViewModel {
        let introParagraphs = [
            GDSLocalisedString(stringKey: "moreAboutDVSParagraph1", dvsName, bundle: .module).value,
            GDSLocalisedString(stringKey: "moreAboutDVSParagraph2", dvsName, bundle: .module).value
        ].joined(separator: "\n\n")

        return GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: introParagraphs),
            accessibilityIdentifier: "more-about-dvs-intro",
            verticalPadding: .bottom(DesignSystem.Spacing.default)
        )
    }

    private static func requiredCertificationsList(dvsName: String) -> GDSListViewModel {
        bulletedList(
            titleKey: "requiredCertificationListTitle",
            dvsName: dvsName,
            itemKeys: [
                "requiredCertificationList1",
                "requiredCertificationList2",
                "requiredCertificationList3"
            ],
            accessibilityIdentifier: "dvs-required-certification-list",
            verticalPadding: .bottom(DesignSystem.Spacing.default)
        )
    }

    private static func privacyPolicyTitle(dvsName: String) -> GDSTextViewModel {
        GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "dvsPrivacyNoticeTitle", dvsName, bundle: .module),
            titleFont: DesignSystem.Font.Base.title2Bold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "dvs-privacy-policy-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )
    }

    private static func privacyPolicyList(dvsName: String) -> GDSListViewModel {
        bulletedList(
            titleKey: "dvsPrivacyNoticeListTitle",
            dvsName: dvsName,
            itemKeys: [
                "dvsPrivacyNoticeList1",
                "dvsPrivacyNoticeList2"
            ],
            accessibilityIdentifier: "dvs-privacy-notice-list",
            verticalPadding: .bottom(DesignSystem.Spacing.small)
        )
    }

    private static func privacyNoticeLink(
        dvsName: String,
        privacyPolicyURL: URL,
        analyticsService: SharingAnalyticsService?
    ) -> GDSButtonViewModel {
        createButtonViewModelWith(
            titleKey: "dvsPrivacyNoticeLink",
            dvsName: dvsName,
            analyticsService: analyticsService
        ) {
            UIApplication.shared.open(url: privacyPolicyURL)
        }
    }

    // MARK: - Builders

    private static func bulletedList(
        titleKey: String,
        dvsName: String,
        itemKeys: [String],
        accessibilityIdentifier: String,
        verticalPadding: VerticalPadding
    ) -> GDSListViewModel {
        GDSListViewModel(
            title: GDSLocalisedString(stringKey: titleKey, dvsName, bundle: .module),
            titleConfig: (font: DesignSystem.Font.Base.body, isHeader: false),
            items: itemKeys.map { GDSLocalisedString(stringKey: $0, bundle: .module) },
            style: .bulleted,
            accessibilityIdentifier: accessibilityIdentifier,
            verticalPadding: verticalPadding
        )
    }

    private static func createButtonViewModelWith(
        titleKey: String,
        dvsName: String,
        analyticsService: SharingAnalyticsService?,
        action: @escaping () -> Void
    ) -> GDSButtonViewModel {
        let title = GDSLocalisedString(
            stringKey: titleKey,
            dvsName,
            bundle: .module
        )
        return GDSButtonViewModel(
            title: title.value,
            icon: .arrowUpRight,
            style: .secondaryLeading,
            buttonAction: .action {
                analyticsService?.trackEvent(.dvsPrivacyPolicyLink)
                action()
            },
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )
    }
}
