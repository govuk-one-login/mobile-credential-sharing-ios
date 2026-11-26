import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

/// A reusable VM for sharing's failure screens.
///
/// All failure screens are pretty similar - an error icon, a title, a body, and one
/// or two buttons - so they are modelled once as a `GDSScreenViewModel` and rendered
/// by `GDSScreen` (see `ResolutionFailureViewController`). Using `GDSScreen` means the
/// buttons live in its movable footer, which moves into the scroll view when it would
/// otherwise take more than a third of the screen (large Dynamic Type, landscape).
///
/// Analytics: Each failure screen has a unique `SharingScreen` passed in at init. The
/// screen-view event is called from `didAppear`, and each button tracks its own
/// `SharingEvent`.
///
/// Buttons: each `FailureButton` carries its own `GDSButtonStyle`. The first is
/// normally `.primary`, with any second button a secondary style.
@MainActor
struct ResolutionFailureViewModel: GDSScreenViewModel, BaseViewModel {
    // MARK: GDSScreenViewModel adherence
    let screenStyle: GDSScreenStyle = .error
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []

    // MARK: BaseViewModel adherence
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action?
    let didDismiss: DesignSystem.Action? = nil

    /// The localised screen title. The same text is rendered in the body's
    /// icon-and-title element.
    let title: GDSLocalisedString

    /// - Arguments:
    ///     - screen: a `SharingScreen` that is recorded when the screen appears and
    ///     used to generate the title copy
    ///     - bodyKeys: a series of keys that are used to generate localised text for the body
    ///     - buttons: one or two buttons, rendered in order in the movable footer
    ///     - errorDescription: the low-level error description recorded as the
    ///     analytics `error_reason` when the screen appears
    ///     - analyticsService: optional for testing purposes
    init(
        screen: SharingScreen,
        bodyKeys: [String],
        buttons: [FailureButton],
        errorDescription: String? = nil,
        analyticsService: SharingAnalyticsService? = nil
    ) {
        // MARK: Generate localised strings from keys
        let title = GDSLocalisedString(stringKey: screen.title.key, bundle: .module)
        self.title = title

        // The error icon-and-title is read by VoiceOver as one "Error: <title>" element
        // and hides the decorative icon itself.
        let iconAndTitle = GDSErrorIconTitleViewModel(
            icon: .error,
            title: title,
            titleFont: DesignSystem.Font.Base.largeTitleBold,
            alignment: .center
        )
        let bodyText = bodyKeys.map { key in
            GDSTextViewModel(
                title: GDSLocalisedString(stringKey: key, bundle: .module),
                titleFont: DesignSystem.Font.Base.body,
                alignment: .center,
                accessibilityIdentifier: key
            )
        }
        self.body = [iconAndTitle] + bodyText

        self.movableFooter = buttons.map { button in
            GDSButtonViewModel(
                title: GDSLocalisedString(stringKey: button.titleKey, bundle: .module).value,
                style: button.style,
                buttonAction: .action {
                    analyticsService?.trackEvent(button.event)
                    Logger.log("Failure screen (\(screen.id)): \(button.accessibilityIdentifier) tapped")
                    button.action()
                },
                accessibilityIdentifier: button.accessibilityIdentifier,
                verticalPadding: .vertical(DesignSystem.Spacing.small),
                horizontalPadding: .horizontal(DesignSystem.Spacing.default)
            )
        }

        self.didAppear = .action {
            analyticsService?.trackScreen(screen, with: errorDescription)
        }
    }
}

extension ResolutionFailureViewModel {
    /// The catch-all "Sharing is currently unavailable" screen, shown for failures
    /// that have no dedicated error screen.
    /// - Parameter errorDescription: low-level error description for analytics `error_reason`
    static func genericError(
        errorDescription: String,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil
    ) -> ResolutionFailureViewModel {
        ResolutionFailureViewModel(
            screen: .genericError,
            bodyKeys: ["genericErrorBody1", "genericErrorBody2"],
            buttons: [
                FailureButton(
                    titleKey: "goBackToDocumentsButton",
                    event: .goBackToDocumentsButton,
                    accessibilityIdentifier: "generic-error-go-back-button",
                    action: { orchestrator.userDidFinish() }
                )
            ],
            errorDescription: errorDescription,
            analyticsService: analyticsService
        )
    }

    /// The "There is a problem" screen, shown when the ReaderAuth COSE check fails.
    /// - Parameter errorDescription: low-level error description for analytics `error_reason`
    static func readerAuthError(
        errorDescription: String,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil
    ) -> ResolutionFailureViewModel {
        ResolutionFailureViewModel(
            screen: .readerAuthError,
            bodyKeys: ["readerAuthErrorBody1", "readerAuthErrorBody2"],
            buttons: [
                FailureButton(
                    titleKey: "goBackToDocumentsButton",
                    event: .goBackToDocumentsButton,
                    accessibilityIdentifier: "reader-auth-error-go-back-button",
                    action: { orchestrator.userDidFinish() }
                )
            ],
            errorDescription: errorDescription,
            analyticsService: analyticsService
        )
    }

    /// The "Bluetooth is turned off" screen, shown when the user turns off Bluetooth
    /// mid-session. Continue starts a new session (which re-runs the prerequisite
    /// gate); Cancel dismisses the journey.
    /// - Parameter errorDescription: low-level error description for analytics `error_reason`
    static func bluetoothOffError(
        errorDescription: String,
        orchestrator: HolderOrchestratorProtocol,
        analyticsService: SharingAnalyticsService? = nil
    ) -> ResolutionFailureViewModel {
        ResolutionFailureViewModel(
            screen: .bluetoothOffError,
            bodyKeys: ["bluetoothOffErrorBody1", "bluetoothOffErrorBody2", "bluetoothOffErrorBody3"],
            buttons: [
                FailureButton(
                    titleKey: "continue",
                    event: .continueButton,
                    accessibilityIdentifier: "bluetooth-off-error-continue-button",
                    action: { orchestrator.startTransaction() }
                ),
                FailureButton(
                    titleKey: "cancelAndGoBackButton",
                    event: .cancelAndGoBackButton,
                    accessibilityIdentifier: "bluetooth-off-error-cancel-button",
                    style: .secondary,
                    action: { orchestrator.userDidFinish() }
                )
            ],
            errorDescription: errorDescription,
            analyticsService: analyticsService
        )
    }
}

/// Lightweight description of a failure screen's button
struct FailureButton {
    let titleKey: String
    let event: SharingEvent
    /// Applied to the rendered button for UI tests. Not read by VoiceOver.
    let accessibilityIdentifier: String
    /// `.primary` unless the screen needs a different treatment, e.g. a secondary
    /// button below the primary one.
    let style: GDSButtonStyle
    let action: () -> Void

    init(
        titleKey: String,
        event: SharingEvent,
        accessibilityIdentifier: String,
        style: GDSButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.event = event
        self.accessibilityIdentifier = accessibilityIdentifier
        self.style = style
        self.action = action
    }
}
