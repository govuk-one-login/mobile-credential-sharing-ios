import DesignSystem
import GDSAnalytics
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate

@MainActor
struct GetReadyToShareViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .top
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = GDSLocalisedString(
        stringKey: "cancel",
        bundle: .module
    )
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action?

    private let presentation: ReadinessPresentation
    private let orchestrator: HolderOrchestratorProtocol

    // swiftlint:disable:next function_body_length
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol
        // inject AnalyticsService
//        analyticsService: SharingAnalyticsService
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator

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
                // call analyticsService.logEvent(_:)
                _ = ButtonEvent(
                    textKey: "getReadyToShareAllowBluetoothButton",
                    bundle: .module
                )
                Logger.log("Get ready to share: Allow Bluetooth tapped")
                guard let bluetoothPrerequisite else {
                    Logger.log("Get ready to share: no Bluetooth prerequisite to resolve", level: .error)
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
        
                _ = ButtonEvent(
                    textKey: "getReadyToShareFindOutHowButton",
                    bundle: .module
                )
                // call analyticsService.logEvent()
                Logger.log("Get ready to share: Find out how sharing works tapped")
            },
            accessibilityIdentifier: "get-ready-to-share-find-out-how-button",
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        self.movableFooter = [allowBluetoothButton, findOutHowButton]

        self.didAppear = .action {
            _ = ScreenView(
                id: AnalyticsScreen.getReadyToShare.id,
                screen: AnalyticsScreen.getReadyToShare,
                titleKey: "getReadyToShareTitle",
                bundle: .module
            )
            Logger.log("Get ready to share screen appeared")
            // call analyticsService.trackScreen(screen)
        }

        self.didDismiss = .action {
            // call analyticsService.logEvent() for Cancel
            _ = ButtonEvent(textKey: "cancel", bundle: .module)
            Logger.log("Get ready to share: Cancel tapped")
            orchestrator.userDidTapCancel()
        }
    }
}
