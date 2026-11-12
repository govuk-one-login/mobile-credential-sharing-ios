import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
struct EngagementViewModel: GDSScreenViewModel, BaseViewModel {
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

    let analyticsService: SharingAnalyticsService?

    /// The title text content, exposed so the landscape two-column layout can re-render it
    /// (see `QRCodeLandscapeView`).
    let titleContent: GDSTextViewModel
    /// The explanatory body copy content, exposed for the landscape layout.
    let bodyContent: [GDSTextViewModel]
    /// The live QR area for the portrait layout, owned by `EngagementViewController` and
    /// inserted into the portrait body here. The landscape layout has its own QR view
    /// (`QRCodeLandscapeView`); the controller refreshes both so the QR updates in place on
    /// expiry regardless of orientation.
    let qrCodeView: QRCodeView

    private let presentation: EngagementPresentation
    private let orchestrator: HolderOrchestratorProtocol

    init(
        presentation: EngagementPresentation,
        orchestrator: HolderOrchestratorProtocol,
        qrCodeView: QRCodeView,
        analyticsService: SharingAnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
        self.qrCodeView = qrCodeView
        self.analyticsService = analyticsService
        self.onCancel = onCancel

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "qrCodeTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "qr-code-title",
            // Keep the 16px gap below the nav bar (top) but only 8px below the title so the
            // gap to the QR white box is 8px (the QR slot adds the other 8). See below.
            verticalPadding: .top(DesignSystem.Spacing.default)
        )

        let bodyParagraph1 = GDSLocalisedString(stringKey: "qrCodeBodyParagraph1", bundle: .module).value
        let bodyParagraph2 = GDSLocalisedString(stringKey: "qrCodeBodyParagraph2", bundle: .module).value
        let bodyParagraph3 = GDSLocalisedString(stringKey: "qrCodeBodyParagraph3", bundle: .module).value
        
        let body1 = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: bodyParagraph1),
            accessibilityIdentifier: "qr-code-body-1",
            // No top margin: the 8px gap above (to the QR white box) is supplied by the QR
            // slot's bottom padding. Keep the default 8px below for inter-paragraph spacing.
            verticalPadding: .bottom(DesignSystem.Spacing.small)
        )
        
        let body2 = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: bodyParagraph2),
            accessibilityIdentifier: "qr-code-body-2"
        )
        
        let body3 = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: bodyParagraph3),
            accessibilityIdentifier: "qr-code-body-3"
        )

        self.titleContent = title
        self.bodyContent = [body1, body2, body3]

        // The QR area is the controller-owned `qrCodeView`, inserted via a passthrough so
        // `GDSScreen` lays it out without freezing a copy. The QR view is a white box with
        // internal padding; in portrait it bleeds to the screen edges (no horizontal margin)
        // so the white reaches both sides, per the design. The 8px vertical padding gives an
        // 8px gap between the title and the white box, and between the white box and the body
        // (the neighbouring title/body items contribute 0 on the sides facing the box).
        let qrSlot = PassthroughContentViewModel(
            view: qrCodeView,
            verticalPadding: .vertical(DesignSystem.Spacing.small),
            horizontalPadding: .horizontal(0)
        )

        // Order follows the design: title, QR code, then the explanatory body copy.
        self.body = [title, qrSlot, body1, body2, body3]

        self.didAppear = .action {
            analyticsService?.trackScreen(.qrCode)
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

// MARK: - Constants
extension EngagementViewModel {
    /// Fixed QR code dimension (width == height) used by the landscape two-column
    /// layout, per the ticket's landscape requirements. The second column renders the
    /// QR code at this size and is not scrollable.
    static let landscapeQRDimension: CGFloat = 250

    /// Accessibility identifier applied to the generated QR image view.
    static let qrImageAccessibilityIdentifier = "qr-code-image"
}
