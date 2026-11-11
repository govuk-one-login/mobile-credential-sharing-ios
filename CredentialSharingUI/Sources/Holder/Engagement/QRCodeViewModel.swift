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

    /// The title text content, exposed so an orientation-aware container can
    /// re-render it in the landscape two-column layout (see `EngagementViewController`).
    let titleContent: GDSTextViewModel
    /// The explanatory body copy content, exposed for the landscape layout.
    let bodyContent: GDSTextViewModel
    /// The QR code / loading content, exposed for the landscape layout.
    let qrContent: [any ContentViewModel]

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

        self.titleContent = title
        self.bodyContent = body
        self.qrContent = qrContent.content

        // In portrait the QR area is a single stack slot. The QR image keeps its natural
        // (width-driven, square) size; the empty/placeholder state is wrapped in a square
        // slot of the same footprint so the body copy below does not shift when the screen
        // swaps between the two states.
        let portraitQRContent: [any ContentViewModel]
        switch qrContent {
        case .qrImage(let image):
            portraitQRContent = [image]
        case .placeholder:
            portraitQRContent = [
                SquareSlotContentViewModel(
                    wrapping: BlankContentViewModel(),
                    accessibilityIdentifier: "qr-code-slot"
                )
            ]
        }

        // Order follows the design: title, QR code, then the explanatory body copy.
        self.body = [title] + portraitQRContent + [body]

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
    /// The outcome of building the QR area, distinguishing the rendered QR image from the
    /// empty/placeholder state so callers can treat them differently (e.g. the portrait
    /// layout wraps the placeholder in a square slot, while landscape does not).
    enum QRContent {
        case qrImage(GDSImageViewModel)
        /// No QR to show yet (session still advertising / refreshing, or generation failed).
        /// Rendered as blank space rather than a spinner.
        case placeholder

        /// The underlying content view model(s) for the landscape column. The QR image
        /// when present; otherwise nothing (the column reserves its own space).
        var content: [any ContentViewModel] {
            switch self {
            case .qrImage(let image): return [image]
            case .placeholder: return []
            }
        }
    }

    /// Fixed QR code dimension (width == height) used by the landscape two-column
    /// layout, per the ticket's landscape requirements. The second column renders the
    /// QR code at this size and is not scrollable.
    static let landscapeQRDimension: CGFloat = 250

    /// Accessibility identifier applied to the generated QR image view. Used by the
    /// landscape layout to apply the fixed 250×250 sizing only to the QR image (and not
    /// to the placeholder).
    static let qrImageAccessibilityIdentifier = "qr-code-image"

    /// QR content for the landscape second column. Reuses the same builder as portrait
    /// (same image / placeholder / failure behaviour); the fixed 250×250 sizing is
    /// applied by the landscape layout in `EngagementViewController`.
    func makeLandscapeQRContent() -> [any ContentViewModel] {
        Self.makeQRContent(
            payload: presentation.qrPayload,
            orchestrator: orchestrator
        ).content
    }

    /// Builds the QR content for the body.
    /// - A non-nil payload renders the generated QR `UIImage`. If generation throws,
    ///   the failure is surfaced to the orchestrator and blank space is shown while the
    ///   session tears down.
    /// - A nil payload is the valid "hidden" state (session still advertising / refreshing),
    ///   so blank space is shown and no failure is reported.
    private static func makeQRContent(
        payload: String?,
        orchestrator: HolderOrchestratorProtocol
    ) -> QRContent {
        guard let payload else {
            return .placeholder
        }

        do {
            let qrCode = try QRGenerator.generateQRCode(from: payload)
            let qrImage = GDSImageViewModel(
                image: qrCode,
                contentMode: .scaleAspectFit,
                accessibilityLabel: GDSLocalisedString(stringKey: "qrCodeAltText", bundle: .module).value,
                accessibilityIdentifier: qrImageAccessibilityIdentifier,
                accessibilityTraits: .image,
                verticalPadding: .vertical(DesignSystem.Spacing.default),
                horizontalPadding: .horizontal(DesignSystem.Spacing.default)
            )
            return .qrImage(qrImage)
        } catch {
            Logger.log("QR code: failed to generate image", level: .error)
            orchestrator.qrCodeGenerationDidFail()
            return .placeholder
        }
    }
}
