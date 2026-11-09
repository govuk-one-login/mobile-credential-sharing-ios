import DesignSystem
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate

@MainActor
struct GetReadyToShareViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .top
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    var rightBarButtons: [DesignSystem.NavigationBarButton]? {
        createCancelButton()
    }
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil
    let onCancel: () -> Void
    
    let analyticsService: SharingAnalyticsService?

    private let presentation: ReadinessPresentation
    private let orchestrator: HolderOrchestratorProtocol

    // swiftlint:disable:next function_body_length
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService
        self.onCancel = onCancel

        let titleString = GDSLocalisedString(stringKey: "getReadyToShareTitle", bundle: .module)
        let title = GDSTextViewModel(
            title: titleString,
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
                analyticsService?.trackEvent(.getReadyToShareAllowBluetoothButton)
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
                analyticsService?.trackEvent(.getReadyToShareFindOutHowButton)
                Logger.log("Get ready to share: Find out how sharing works tapped")
            },
            accessibilityIdentifier: "get-ready-to-share-find-out-how-button",
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )

        self.movableFooter = [allowBluetoothButton, findOutHowButton]

        self.didAppear = .action {
            analyticsService?.trackScreen(.getReadyToShare)
        }

    }
    
    private func createCancelButton() -> [DesignSystem.NavigationBarButton]? {
        return if presentation.cancelRequiresConfirmation != nil {
            [DesignSystem.NavigationBarButton.button(
                title: GDSLocalisedString(
                    stringKey: "cancel",
                    bundle: .module
                ).value,
                style: .plain,
                accessibilityIdentifier: "right-bar-button",
                action: {
                    analyticsService?.trackEvent(.cancel)
                    onCancel()
                }
            )]
        } else {
            nil
        }
    }
}
