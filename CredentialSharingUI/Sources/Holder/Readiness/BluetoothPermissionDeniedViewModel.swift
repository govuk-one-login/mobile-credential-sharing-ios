import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
struct BluetoothPermissionDeniedViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .error
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let rightBarButtons: [DesignSystem.NavigationBarButton]? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didDismiss: DesignSystem.Action? = nil
    
    var body: [any ContentViewModel] {
        [
            GDSErrorIconTitleViewModel(
                icon: .error,
                errorTitle: GDSTextViewModel(
                    title: GDSLocalisedString(stringKey: "bluetoothDeniedTitle", bundle: .module),
                    titleFont: DesignSystem.Font.Base.title1Bold,
                    alignment: .center,
                    accessibilityTraits: .header
                ),
                accessibilityIdentifier: "bluetooth-denied-title"
            ),
            Self.bodyText(
                "bluetoothDeniedParagraph1",
                accessibilityIdentifier: "bluetooth-denied-body",
                verticalPadding: .bottom(DesignSystem.Spacing.default)
            ),
            GDSListViewModel(
                title: GDSLocalisedString(stringKey: "bluetoothDeniedListTitle", bundle: .module),
                titleConfig: (font: DesignSystem.Font.Base.body, isHeader: false),
                items: [
                    GDSLocalisedString(stringKey: "bluetoothDeniedStep1", bundle: .module),
                    GDSLocalisedString(stringKey: "bluetoothDeniedStep2", bundle: .module)
                ],
                style: .numbered,
                accessibilityIdentifier: "bluetooth-denied-steps",
                verticalPadding: .bottom(DesignSystem.Spacing.default)
            ),
            Self.bodyText(
                "bluetoothDeniedParagraph2",
                accessibilityIdentifier: "bluetooth-denied-footnote",
                verticalPadding: .vertical(.zero)
            )
        ]
    }

    var movableFooter: [any ContentViewModel] {
        [
            GDSButtonViewModel(
                title: GDSLocalisedString(stringKey: "goToPhoneSettingsButton", bundle: .module).value,
                icon: IconStyle(
                    icon: "arrow.up.right",
                    position: .trailing,
                    accessibilityHint: GDSLocalisedString(
                        stringKey: "goToPhoneSettingsAccessibilityHint",
                        bundle: .module
                    ).value
                ),
                style: .primary,
                buttonAction: .action {
                    analyticsService?.trackEvent(.goToPhoneSettingsButton)
                    openSettings()
                },
                accessibilityIdentifier: "bluetooth-denied-go-to-settings-button",
                verticalPadding: .vertical(DesignSystem.Spacing.default),
                horizontalPadding: .horizontal(DesignSystem.Spacing.default)
            ),
            GDSButtonViewModel(
                title: GDSLocalisedString(stringKey: "cancelAndGoBackToDocumentsButton", bundle: .module).value,
                style: .secondary,
                buttonAction: .action {
                    analyticsService?.trackEvent(.cancelAndGoBackButton)
                    onCancel()
                },
                accessibilityIdentifier: "bluetooth-denied-cancel-button",
                verticalPadding: .vertical(.zero),
                horizontalPadding: .horizontal(DesignSystem.Spacing.default)
            )
        ]
    }
    var didAppear: DesignSystem.Action? {
        .action {
            analyticsService?.trackScreen(.bluetoothPermissionDenied)
        }
    }
    
    let onCancel: () -> Void
    let analyticsService: SharingAnalyticsService?
    private let openSettings: @MainActor () -> Void

    init(
        analyticsService: SharingAnalyticsService? = nil,
        openSettings: @escaping @MainActor () -> Void = Self.openAppSettings,
        onCancel: @escaping () -> Void
    ) {
        self.analyticsService = analyticsService
        self.openSettings = openSettings
        self.onCancel = onCancel
    }

    private static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            Logger.log("Bluetooth denied: unable to build Settings URL", level: .error)
            return
        }
        UIApplication.shared.open(url)
    }
    
    static func bodyText(
        _ key: String,
        accessibilityIdentifier: String,
        verticalPadding: VerticalPadding
    ) -> GDSTextViewModel {
        GDSTextViewModel(
            title: GDSLocalisedString(
                stringKey: key,
                bundle: .module
            ),
            titleFont: DesignSystem.Font.Base.body,
            textColor: DesignSystem.Color.Text.primary,
            alignment: .center,
            accessibilityIdentifier: accessibilityIdentifier,
            verticalPadding: verticalPadding
        )
    }
}
