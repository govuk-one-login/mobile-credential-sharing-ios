import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
struct BluetoothRestrictedViewModel: GDSScreenViewModel, BaseViewModel {
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
                    title: GDSLocalisedString(stringKey: "bluetoothRestrictedTitle", bundle: .module),
                    titleFont: DesignSystem.Font.Base.title1Bold,
                    alignment: .center,
                    accessibilityTraits: .header
                ),
                accessibilityIdentifier: "bluetooth-restricted-title"
            ),
            Self.bodyText(
                "bluetoothRestrictedParagraph1",
                accessibilityIdentifier: "bluetooth-restricted-body1",
                verticalPadding: .bottom(DesignSystem.Spacing.default)
            ),
            Self.bodyText(
                "bluetoothRestrictedParagraph2",
                boldKey: "bluetoothRestrictedParagraph2Bold",
                accessibilityIdentifier: "bluetooth-restricted-body2",
                verticalPadding: .bottom(DesignSystem.Spacing.default)
            ),
            Self.bodyText(
                "bluetoothRestrictedParagraph3",
                accessibilityIdentifier: "bluetooth-restricted-body3",
                verticalPadding: .vertical(.zero)
            )
        ]
    }

    var movableFooter: [any ContentViewModel] {
        [
            GDSButtonViewModel(
                title: GDSLocalisedString(stringKey: "goBackToDocumentsButton", bundle: .module).value,
                style: .primary,
                buttonAction: .action { [analyticsService, onCancel] in
                    analyticsService?.trackEvent(.goBackToDocumentsButton)
                    onCancel()
                },
                accessibilityIdentifier: "go-back-to-documents-button",
                horizontalPadding: .horizontal(DesignSystem.Spacing.default)
            )
        ]
    }

    var didAppear: DesignSystem.Action? {
        .action {
            analyticsService?.trackScreen(.bluetoothRestricted)
        }
    }
    
    let onCancel: () -> Void
    let analyticsService: SharingAnalyticsService?

    init(
        analyticsService: SharingAnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.analyticsService = analyticsService
        self.onCancel = onCancel
    }
    
    static func bodyText(
        _ key: String,
        boldKey: String? = nil,
        accessibilityIdentifier: String,
        verticalPadding: VerticalPadding
    ) -> GDSTextViewModel {
        let title: GDSLocalisedString
        if let boldKey {
            title = GDSLocalisedString(
                stringKey: key,
                stringAttributes: [
                    (GDSLocalisedString(stringKey: boldKey, bundle: .module).value,
                     [.font: DesignSystem.Font.Base.bodySemiBold])
                ],
                bundle: .module
            )
        } else {
            title = GDSLocalisedString(stringKey: key, bundle: .module)
        }
        return GDSTextViewModel(
            title: title,
            titleFont: DesignSystem.Font.Base.body,
            textColor: DesignSystem.Color.Text.primary,
            alignment: .center,
            accessibilityIdentifier: accessibilityIdentifier,
            verticalPadding: verticalPadding
        )
    }
}
