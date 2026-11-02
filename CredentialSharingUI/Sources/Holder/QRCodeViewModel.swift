import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
struct QRCodeViewModel: GDSScreenViewModel, BaseViewModel {
    /// Fixed size of the rendered QR code, per the design spec.
    private static let qrCodeSize: CGFloat = 250

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

    private let presentation: EngagementPresentation

    init(
        presentation: EngagementPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: AnalyticsService? = nil,
        onCancel: @escaping () -> Void,
        onQRGenerationFailure: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.analyticsService = analyticsService
        self.onCancel = onCancel

        let title = GDSTextViewModel(
            title: GDSLocalisedString(stringKey: "qrCodeTitle", bundle: .module),
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            accessibilityTraits: .header,
            accessibilityIdentifier: "qr-code-title",
            verticalPadding: .vertical(DesignSystem.Spacing.default)
        )

        let bodyParagraphs = [
            GDSLocalisedString(stringKey: "qrCodeBodyParagraph1", bundle: .module).value,
            GDSLocalisedString(stringKey: "qrCodeBodyParagraph2", bundle: .module).value,
            GDSLocalisedString(stringKey: "qrCodeBodyParagraph3", bundle: .module).value
        ].joined(separator: "\n\n")

        let body = GDSTextViewModel(
            title: GDSLocalisedString(stringLiteral: bodyParagraphs),
            accessibilityIdentifier: "qr-code-body"
        )

        self.body = [title, body] + Self.makeQRContent(
            payload: presentation.qrPayload,
            onQRGenerationFailure: onQRGenerationFailure
        )

        self.didAppear = .action {
            analyticsService?.trackScreenEvent(
                ScreenViewEventName.screenView,
                title: AnalyticsScreen.qrCode.rawValue,
                screenClass: .modal,
                screenID: AnalyticsScreen.qrCode.id,
            )
        }
    }

    /// Builds the QR content for the body.
    /// - A non-nil payload renders the generated QR `UIImage`. If generation throws,
    ///   the failure is surfaced via `onQRGenerationFailure` and a spinner is shown
    ///   while the session tears down.
    /// - A nil payload is the valid "hidden" state (session still advertising / refreshing),
    ///   so a spinner is shown and no failure is reported.
    private static func makeQRContent(
        payload: String?,
        onQRGenerationFailure: @escaping () -> Void
    ) -> [any ContentViewModel] {
        guard let payload else {
            return [loadingIndicator()]
        }

        do {
            let qrCode = try QRGenerator(path: payload).generateQRCode()
            let qrImage = GDSImageViewModel(
                image: qrCode,
                contentMode: .scaleAspectFit,
                imageFixedHeight: qrCodeSize,
                accessibilityLabel: GDSLocalisedString(stringKey: "qrCodeAltText", bundle: .module).value,
                accessibilityIdentifier: "qr-code-image",
                accessibilityTraits: .image,
                verticalPadding: .vertical(DesignSystem.Spacing.default)
            )
            return [qrImage]
        } catch {
            Logger.log("QR code: failed to generate image", level: .error)
            onQRGenerationFailure()
            return [loadingIndicator()]
        }
    }

    private static func loadingIndicator() -> GDSProgressIndicatorViewModel {
        GDSProgressIndicatorViewModel(accessibilityIdentifier: "qr-code-loading")
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
