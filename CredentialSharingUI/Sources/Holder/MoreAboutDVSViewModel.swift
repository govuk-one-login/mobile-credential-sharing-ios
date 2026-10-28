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
    let rightBarButtonTitle: GDSLocalisedString? = GDSLocalisedString(
        stringKey: "close",
        bundle: .module
    )
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action?
    
    let analyticsService: AnalyticsService?
    private let orchestrator: HolderOrchestratorProtocol
    private let presentation: ConsentPresentation
    
    let opener: SharingURLOpener? = nil ?? UIApplication.shared
    
    // swiftlint:disable:next function_body_length
    init(
        presentation: ConsentPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService
        
        let moreAboutDVStitle = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "moreAboutDVSTitle", presentation.dvsName, bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "more-about-dvs-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )
        
        let introParagraphs = [
            GDSLocalisedString(stringKey: "moreAboutDVSParagraph1", presentation.dvsName, bundle: .module).value,
            GDSLocalisedString(stringKey: "moreAboutDVSParagraph2", presentation.dvsName, bundle: .module).value
        ].joined(separator: "\n\n")

        let intro = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: introParagraphs),
            accessibilityIdentifier: "more-about-dvs-intro"
        )

        let requiredCertificationsList = GDSListViewModel(
            title: GDSLocalisedString(stringKey: "requiredCertificationListTitle", presentation.dvsName, bundle: .module),
            titleConfig: (font: DesignSystem.Font.Base.body, isHeader: false),
            items: [
                GDSLocalisedString(
                    stringKey: "requiredCertificationList1",
                    bundle: .module
                ),
                GDSLocalisedString(
                    stringKey: "requiredCertificationList2",
                    bundle: .module
                ),
                GDSLocalisedString(
                    stringKey: "requiredCertificationList3",
                    bundle: .module
                )
            ],
            style: .bulleted,
            accessibilityIdentifier: "dvs-required-certification-list",
            verticalPadding: .bottom(DesignSystem.Spacing.xLarge)
        )
        
        let dvsPrivacyPolicyTitle = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "dvsPrivacyNoticeTitle", presentation.dvsName, bundle: .module),
            titleFont: DesignSystem.Font.Base.title2Bold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "dvs-privacy-policy-title",
            verticalPadding: .bottom(DesignSystem.Spacing.default)
        )

        let dvsPrivacyPolicyList = GDSListViewModel(
            title: GDSLocalisedString(stringKey: "dvsPrivacyNoticeListTitle", presentation.dvsName, bundle: .module),
            titleConfig: (font: DesignSystem.Font.Base.body, isHeader: false),
            items: [
                GDSLocalisedString(
                    stringKey: "dvsPrivacyNoticeList1",
                    bundle: .module
                ),
                GDSLocalisedString(
                    stringKey: "dvsPrivacyNoticeList2",
                    bundle: .module
                )
            ],
            style: .bulleted,
            accessibilityIdentifier: "dvs-required-certification-list",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )
        
        let dvsPrivacyNoticeExternalLink = Self.createButtonViewModelWith(
            titleKey: "dvsPrivacyNoticeLink",
            dvsName: presentation.dvsName,
            analyticsService: analyticsService
        ) {
            UIApplication.shared.open(url: presentation.privacyPolicyURL)
        }

        self.body = [
            moreAboutDVStitle,
            intro,
            requiredCertificationsList,
            dvsPrivacyPolicyTitle,
            dvsPrivacyPolicyList,
            dvsPrivacyNoticeExternalLink
        ]

        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: AnalyticsScreen.moreAboutDVS.rawValue,
                screenClass: .modal,
                screenID: AnalyticsScreen.moreAboutDVS.id,
            )
        }

        self.didDismiss = .action {
            let event = ButtonEvent(textKey: "close", bundle: .module)
            analyticsService?.trackButtonEvent(event)
            orchestrator.userDidTapCancel()
        }
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
