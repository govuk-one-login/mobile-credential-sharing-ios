import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate

@MainActor
struct BluetoothPoweredOffViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .top
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel] = []
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

    let analyticsService: AnalyticsService?
    private let presentation: ReadinessPresentation
    private let orchestrator: HolderOrchestratorProtocol
    
    // swiftlint:disable:next function_body_length
    init(
        presentation: ReadinessPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
        self.analyticsService = analyticsService
        self.onCancel = onCancel

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "turnOnBluetoothTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "turn-on-bluetooth-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        let intro = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "turnOnBluetoothParagraph1", bundle: .module),
            accessibilityIdentifier: "turn-on-bluetooth-body"
        )

        let steps = GDSListViewModel(
            title: GDSLocalisedString(stringKey: "turnOnBluetoothListTitle", bundle: .module),
            titleConfig: (font: DesignSystem.Font.Base.body, isHeader: false),
            items: [
                GDSLocalisedString(
                    stringKey: "turnOnBluetoothStep1",
                    stringAttributes: [
                        (GDSLocalisedString(stringKey: "turnOnBluetoothStep1Bold", bundle: .module).value,
                         [.font: DesignSystem.Font.Base.bodySemiBold])
                    ],
                    bundle: .module
                ),
                GDSLocalisedString(
                    stringKey: "turnOnBluetoothStep2",
                    stringAttributes: [
                        (GDSLocalisedString(stringKey: "turnOnBluetoothStep2Bold", bundle: .module).value,
                         [.font: DesignSystem.Font.Base.bodySemiBold])
                    ],
                    bundle: .module
                ),
                GDSLocalisedString(stringKey: "turnOnBluetoothStep3", bundle: .module)
            ],
            style: .numbered,
            accessibilityIdentifier: "turn-on-bluetooth-steps",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        let footnote = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "turnOnBluetoothParagraph2", bundle: .module),
            accessibilityIdentifier: "turn-on-bluetooth-footnote"
        )

        self.body = [title, intro, steps, footnote]

        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: AnalyticsScreen.turnOnBluetooth.rawValue,
                screenClass: .modal,
                screenID: AnalyticsScreen.turnOnBluetooth.id,
            )
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
                    let event = ButtonEvent(textKey: "cancel", bundle: .module)
                    analyticsService?.trackButtonEvent(event)
                    onCancel()
                }
            )]
        } else {
            nil
        }
    }
}
