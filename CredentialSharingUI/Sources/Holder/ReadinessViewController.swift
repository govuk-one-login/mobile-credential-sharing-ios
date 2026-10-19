import DesignSystem
import GDSAnalytics
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate

// MARK: ReadinessViewController

@MainActor
final class ReadinessViewController: GDSScreen {
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol
    ) {
        super.init(
            viewModel: ReadinessViewModel(
                presentation: presentation,
                orchestrator: orchestrator
            )
        )
    }
}

// MARK: ReadinessViewModel

@MainActor
struct ReadinessViewModel: GDSScreenViewModel, BaseViewModel {
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
            title: GDSLocalisedString(stringKey: "readinessTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "readiness-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )
        
        let bodyParagraphs = [
            GDSLocalisedString(stringKey: "readinessBodyParagraph1", bundle: .module).value,
            GDSLocalisedString(stringKey: "readinessBodyParagraph2", bundle: .module).value,
            GDSLocalisedString(stringKey: "readinessBodyParagraph3", bundle: .module).value
        ].joined(separator: "\n\n")

        let body = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: bodyParagraphs),
            accessibilityIdentifier: "readiness-body"
        )

        self.body = [title, body]

        // To trigger the Bluetooth OS permission prompt via the Gate's
        // existing resolution loop. The resolver re-runs preflight on completion.
        let bluetoothPrerequisite = presentation.missingPrerequisites.first {
            $0.prerequisite == .bluetooth
        }

        let allowBluetoothButton = GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "readinessAllowBluetoothButton", bundle: .module).value,
            style: .primary,
            buttonAction: .action {
                // call analyticsService.logEvent(_:)
                _ = ButtonEvent(
                    textKey: "readinessAllowBluetoothButton",
                    bundle: .module
                )
                Logger.log("Readiness: Allow Bluetooth tapped")
                guard let bluetoothPrerequisite else {
                    Logger.log("Readiness: no Bluetooth prerequisite to resolve", level: .error)
                    return
                }
                orchestrator.resolve(bluetoothPrerequisite)
            },
            accessibilityIdentifier: "readiness-allow-bluetooth-button",
            verticalPadding: .vertical(DesignSystem.Spacing.default),
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        let findOutHowButton = GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "readinessFindOutHowButton", bundle: .module).value,
            style: .secondary,
            buttonAction: .action {
        
                _ = ButtonEvent(
                    textKey: "readinessFindOutHowButton",
                    bundle: .module
                )
                // call analyticsService.logEvent()
                Logger.log("Readiness: Find out how sharing works tapped")
            },
            accessibilityIdentifier: "readiness-find-out-how-button",
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        self.movableFooter = [allowBluetoothButton, findOutHowButton]

        self.didAppear = .action {
            _ = ScreenView(
                id: AnalyticsScreen.readiness.id,
                screen: AnalyticsScreen.readiness,
                titleKey: "readinessTitle",
                bundle: .module
            )
            Logger.log("Readiness screen appeared")
            // call analyticsService.trackScreen(screen)
        }

        self.didDismiss = .action {
            // call analyticsService.logEvent() for Cancel
            _ = ButtonEvent(textKey: "cancel", bundle: .module)
            Logger.log("Readiness: Cancel tapped")
            orchestrator.userDidTapCancel()
        }
    }
}
