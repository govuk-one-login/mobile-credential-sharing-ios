import DesignSystem
import Foundation
import GDSAnalytics
import Logging
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

    let analyticsService: AnalyticsService?

    init(
        presentation: ConsentPresentation,
        analyticsService: AnalyticsService? = nil,
        onClose: @escaping () -> Void = {}
    ) {
        self.analyticsService = analyticsService

        self.rightBarButtons = [
            Self.closeButton(analyticsService: analyticsService, onClose: onClose)
        ]

        self.body = [
            Self.titleViewModel(dvsName: presentation.dvsName),
            Self.introViewModel(dvsName: presentation.dvsName),
            Self.requiredCertificationsList(dvsName: presentation.dvsName),
            Self.privacyPolicyTitle(dvsName: presentation.dvsName),
            Self.privacyPolicyList(dvsName: presentation.dvsName),
            Self.privacyNoticeLink(
                dvsName: presentation.dvsName,
                privacyPolicyURL: presentation.privacyPolicyURL,
                analyticsService: analyticsService
            )
        ]

        self.didAppear = Self.screenViewAction(analyticsService: analyticsService)
    }

    // MARK: - Bar buttons

    private static func closeButton(
        analyticsService: AnalyticsService?,
        onClose: @escaping () -> Void
    ) -> DesignSystem.NavigationBarButton {
        .button(
            title: GDSLocalisedString(stringKey: "close", bundle: .module).value,
            accessibilityIdentifier: "more-about-dvs-close-button",
            action: {
                analyticsService?.trackButtonEvent(ButtonEvent(textKey: "close", bundle: .module))
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
            accessibilityIdentifier: "more-about-dvs-intro"
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
            verticalPadding: .bottom(DesignSystem.Spacing.xLarge)
        )
    }

    private static func privacyPolicyTitle(dvsName: String) -> GDSTextViewModel {
        GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "dvsPrivacyNoticeTitle", dvsName, bundle: .module),
            titleFont: DesignSystem.Font.Base.title2Bold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "dvs-privacy-policy-title",
            verticalPadding: .bottom(DesignSystem.Spacing.default)
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
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )
    }

    private static func privacyNoticeLink(
        dvsName: String,
        privacyPolicyURL: URL,
        analyticsService: AnalyticsService?
    ) -> GDSButtonViewModel {
        createButtonViewModelWith(
            titleKey: "dvsPrivacyNoticeLink",
            dvsName: dvsName,
            analyticsService: analyticsService
        ) {
            UIApplication.shared.open(url: privacyPolicyURL)
        }
    }

    // MARK: - Analytics

    private static func screenViewAction(analyticsService: AnalyticsService?) -> DesignSystem.Action {
        .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: AnalyticsScreen.moreAboutDVS.rawValue,
                screenClass: .modal,
                screenID: AnalyticsScreen.moreAboutDVS.id,
            )
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
        analyticsService: AnalyticsService?,
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
                let event = ButtonEvent(
                    textKey: title.stringKey,
                    variableKeys: title.variableKeys,
                    bundle: .module
                )

                analyticsService?.trackButtonEvent(event)
                action()
            },
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )
    }
}
