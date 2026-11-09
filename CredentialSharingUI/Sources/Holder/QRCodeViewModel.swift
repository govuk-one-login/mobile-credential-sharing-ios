import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
struct QRCodeViewModel: GDSScreenViewModel, BaseViewModel {
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

    private let presentation: EngagementPresentation
    private let orchestrator: HolderOrchestratorProtocol

    init(
        presentation: EngagementPresentation,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.orchestrator = orchestrator
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

        let qrContent = Self.makeQRContent(
            payload: presentation.qrPayload,
            orchestrator: orchestrator
        )

        // Order follows the design: title, QR code, then the explanatory body copy.
        self.body = [title] + qrContent + [body]

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

// MARK: - Static content builder funcs
extension QRCodeViewModel {
    /// Builds the QR content for the body.
    /// - A non-nil payload renders the generated QR `UIImage`. If generation throws,
    ///   the failure is surfaced to the orchestrator and a spinner is shown while the
    ///   session tears down.
    /// - A nil payload is the valid "hidden" state (session still advertising / refreshing),
    ///   so a spinner is shown and no failure is reported.
    private static func makeQRContent(
        payload: String?,
        orchestrator: HolderOrchestratorProtocol
    ) -> [any ContentViewModel] {
        guard let payload else {
            return [loadingIndicator()]
        }

        do {
            let qrCode = try QRGenerator(path: payload).generateQRCode()
            let qrImage = GDSImageViewModel(
                image: qrCode,
                contentMode: .scaleAspectFit,
                accessibilityLabel: GDSLocalisedString(stringKey: "qrCodeAltText", bundle: .module).value,
                accessibilityIdentifier: "qr-code-image",
                accessibilityTraits: .image,
                verticalPadding: .vertical(DesignSystem.Spacing.default),
                horizontalPadding: .horizontal(DesignSystem.Spacing.default)
            )
            return [qrImage]
        } catch {
            Logger.log("QR code: failed to generate image", level: .error)
            orchestrator.qrCodeGenerationDidFail()
            return [loadingIndicator()]
        }
    }

    private static func loadingIndicator() -> GDSProgressIndicatorViewModel {
        GDSProgressIndicatorViewModel(accessibilityIdentifier: "qr-code-loading")
    }
}
