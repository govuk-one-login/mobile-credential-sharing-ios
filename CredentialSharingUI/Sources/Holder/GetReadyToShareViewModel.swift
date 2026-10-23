import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate

@MainActor
struct GetReadyToShareViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .top
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    var rightBarButtonTitle: GDSLocalisedString? {
        return presentation.cancelRequiresConfirmation != nil ? GDSLocalisedString(
            stringKey: "cancel",
            bundle: .module
        ) : nil
    }
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action?
    
    let analyticsService: AnalyticsService?
    private let presentation: ReadinessPresentation
    private let orchestrator: HolderOrchestratorProtocol

    // swiftlint:disable:next function_body_length
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "getReadyToShareTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "get-ready-to-share-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )
        
        let bodyParagraphs = [
            GDSLocalisedString(stringKey: "getReadyToShareBodyParagraph1", bundle: .module).value,
            GDSLocalisedString(stringKey: "getReadyToShareBodyParagraph2", bundle: .module).value,
            GDSLocalisedString(stringKey: "getReadyToShareBodyParagraph3", bundle: .module).value
        ].joined(separator: "\n\n")

        let body = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: bodyParagraphs),
            accessibilityIdentifier: "get-ready-to-share-body"
        )

        self.body = [title, body]

        // To trigger the Bluetooth OS permission prompt via the Gate's
        // existing resolution loop. The resolver re-runs preflight on completion.
        let bluetoothPrerequisite = presentation.missingPrerequisites.first {
            $0.prerequisite == .bluetooth
        }

        let allowBluetoothButton = GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "getReadyToShareAllowBluetoothButton", bundle: .module).value,
            style: .primary,
            buttonAction: .action {
                let event = ButtonEvent(
                    textKey: "getReadyToShareAllowBluetoothButton",
                    bundle: .module
                )
                
                analyticsService?.trackButtonEvent(event)
                guard let bluetoothPrerequisite else {
                    Logger.log("Get ready to share: no Bluetooth prerequisite to resolve")
                    return
                }
                orchestrator.resolve(bluetoothPrerequisite)
            },
            accessibilityIdentifier: "get-ready-to-share-allow-bluetooth-button",
            verticalPadding: .vertical(DesignSystem.Spacing.default),
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        let findOutHowButton = GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "getReadyToShareFindOutHowButton", bundle: .module).value,
            style: .secondary,
            buttonAction: .action {
                let event = ButtonEvent(
                    textKey: "getReadyToShareFindOutHowButton",
                    bundle: .module
                )
                analyticsService?.trackButtonEvent(event)
                Logger.log("Get ready to share: Find out how sharing works tapped")
            },
            accessibilityIdentifier: "get-ready-to-share-find-out-how-button",
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        self.movableFooter = [allowBluetoothButton, findOutHowButton]

        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: AnalyticsScreen.getReadyToShare.rawValue,
                screenClass: .modal,
                screenID: AnalyticsScreen.getReadyToShare.id,
            )
        }

        self.didDismiss = .action {
            let event = ButtonEvent(textKey: "cancel", bundle: .module)
            analyticsService?.trackButtonEvent(event)
            orchestrator.userDidTapCancel()
        }
    }
}
