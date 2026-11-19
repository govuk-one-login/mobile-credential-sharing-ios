import GDSCommon
import SharingLogging
import SharingOrchestration
import UIKit

/// A reusable VM for sharing's failure screens.
///
/// All failure screens are pretty similar - a fixed icon, a title, a body, and one or two buttons.
/// So we can model them with `GDSErrorViewModelV3`,  and render them using
/// `GDSErrorScreen`.
///
/// Analytics: Each failure screen has a unique `SharingScreen` passed in at init. The
/// screen-view event is called from `didAppear`, and each button tracks its own
/// `SharingEvent`.
///
/// Buttons: The first button in `buttons` is rendered as the primary `RoundedButton`
/// a second optional button is rendered as a `SecondaryButton`.
@MainActor
struct ResolutionFailureViewModel: GDSErrorViewModelV3, BaseViewModel {
    // MARK: GDSErrorVM Protocol adherence
    let title: GDSLocalisedString
    let bodyContent: [ScreenBodyItem]
    let buttonViewModels: [ButtonViewModel]
    
    // Fixed across all Error screens
    let image: ErrorScreenImage = .error
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    
    private let screen: SharingScreen
    private let analyticsService: SharingAnalyticsService?
    /// Low-level `SessionError.errorDescription`, sent as the analytics `error_reason`.
    private let errorDescription: String?
    
    /// - Arguments:
    ///     - screen: a `SharingScreen` that is recorded in `didAppear` and used to
    ///     generate the title copy
    ///     - bodyKeys: a series of keys that are used to generate localised text for the body
    ///     - buttons: one or two buttons, The first renders to a `RoundedButton` the
    ///     second as a `SecondaryButton`
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
        // MARK: Analytics
        self.screen = screen
        self.analyticsService = analyticsService
        self.errorDescription = errorDescription
        
        // MARK: Generate localised strings from keys
        self.title = GDSLocalisedString(stringKey: screen.titleKey, bundle: .module)
        self.bodyContent = bodyKeys.map {
            BodyTextViewModel(text:
                GDSLocalisedString(stringKey: $0, bundle: .module)
            )
        }
        self.buttonViewModels = buttons.map { button in
            FailureButtonViewModel(
                title: GDSLocalisedString(stringKey: button.titleKey, bundle: .module),
                action: {
                    analyticsService?.trackEvent(button.event)
                    Logger.log("Failure screen (\(screen.id)): \(button.accessibilityIdentifier) tapped")
                    button.action()
                }
            )
        }
    }
    
    // MARK: BaseVM protocol adherence
    func didAppear() {
        analyticsService?.trackScreen(screen, with: errorDescription)
    }
    func didDismiss() {
        // required for protocol conformance
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
}

/// Lightweight description of a failure screen's button
struct FailureButton {
    let titleKey: String
    let event: SharingEvent
    let accessibilityIdentifier: String
    let action: () -> Void
}

/// `DesignSystem.GDSButtonViewModel` conforms to `ContentViewModel` not
/// GDSCommon's `ButtonViewModel`, so we need this local conformance.
@MainActor
private struct FailureButtonViewModel: ButtonViewModel {
    let title: GDSLocalisedString
    let icon: ButtonIconViewModel? = nil
    let shouldLoadOnTap: Bool = true
    let action: () -> Void
}
