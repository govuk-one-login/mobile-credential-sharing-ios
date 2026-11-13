import GDSCommon
import SharingLogging
import SharingOrchestration
import UIKit

/// Shared, reusable view model for the sharing flow's terminal failure screens.
///
/// All failure screens share the same shape — a single fixed icon, a title, a
/// body, and one or two buttons — so they are modelled with one concrete
/// ``GDSErrorViewModelV3`` instead of a bespoke view model per screen, and
/// rendered by `GDSErrorScreen`.
///
/// Analytics identity is baked in: each failure screen is a distinct
/// ``SharingScreen`` passed at construction. The screen-view event fires from
/// `didAppear`, and each button tracks its own ``SharingEvent``, so tracking
/// stays uniform across every failure screen without per-call-site wiring.
///
/// Buttons are supplied by the call site (`buttons`) because the actions differ
/// per failure — one screen may offer a single "Go back", another a retry plus
/// a dismiss. The first button renders as the primary `RoundedButton`, a second
/// (optional) as a `SecondaryButton`.
///
/// Per new failure-screen ticket, the work reduces to:
///   1. Add a distinct ``SharingScreen`` case (id / titleKey / screenClass).
///   2. Add the title/body localized strings.
///   3. Construct a ``ResolutionFailureViewModel`` with 1–2 ``FailureButton``s
///      and wrap it in `GDSErrorScreen(viewModel:)`.
@MainActor
struct ResolutionFailureViewModel: GDSErrorViewModelV3, BaseViewModel {

    // MARK: GDSErrorViewModelV3

    /// Fixed across all failure screens.
    let image: ErrorScreenImage = .error
    let title: GDSLocalisedString
    let bodyContent: [ScreenBodyItem]
    let buttonViewModels: [ButtonViewModel]

    // MARK: BaseViewModel

    // Failure screens have no nav-bar controls; `GDSErrorScreen` renders its own
    // buttons in the bottom stack.
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true

    private let screen: SharingScreen
    private let analyticsService: SharingAnalyticsService?

    /// - Parameters:
    ///   - screen: The analytics identity for this failure screen. Drives both the
    ///     `didAppear` screen-view event and the title copy (`screen.titleKey`).
    ///   - bodyKey: Localized body copy key, resolved against the UI module.
    ///   - buttons: One or two buttons, supplied by the call site. The first renders
    ///     as the primary `RoundedButton`; a second (optional) as a `SecondaryButton`.
    ///   - analyticsService: Injected; defaults to `nil` to keep previews/tests light.
    init(
        screen: SharingScreen,
        bodyKey: String,
        buttons: [FailureButton],
        analyticsService: SharingAnalyticsService? = nil
    ) {
        self.screen = screen
        self.analyticsService = analyticsService
        self.title = GDSLocalisedString(stringKey: screen.titleKey, bundle: .module)
        self.bodyContent = [
            BodyTextViewModel(
                text: GDSLocalisedString(stringKey: bodyKey, bundle: .module)
            )
        ]

        // Map each call-site `FailureButton` to a GDSCommon `ButtonViewModel`,
        // wrapping the tap so the button's analytics event fires before its action.
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

    // MARK: BaseViewModel lifecycle

    func didAppear() {
        analyticsService?.trackScreen(screen)
        Logger.log("Failure screen appeared: \(screen.id)")
    }

    func didDismiss() {}
}

/// Lightweight, call-site-facing description of a failure-screen button.
/// Keeps each ticket's construction declarative — no GDSCommon types at the call site.
struct FailureButton {
    let titleKey: String
    let event: SharingEvent
    let accessibilityIdentifier: String
    let action: () -> Void
}

/// Concrete GDSCommon `ButtonViewModel` conformance used by the failure template.
///
/// `DesignSystem.GDSButtonViewModel` conforms to `ContentViewModel`/`ControlViewModel`,
/// not GDSCommon's `ButtonViewModel`, so `GDSErrorScreen` (a GDSCommon screen)
/// needs this local conformance.
@MainActor
private struct FailureButtonViewModel: ButtonViewModel {
    let title: GDSLocalisedString
    let action: () -> Void

    let icon: ButtonIconViewModel? = nil
    let shouldLoadOnTap: Bool = true
}

#if DEBUG
import SwiftUI

/// Bridges the UIKit `GDSErrorScreen` into a SwiftUI `#Preview`.
private struct FailureScreenPreview: UIViewControllerRepresentable {
    let viewModel: ResolutionFailureViewModel

    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: GDSErrorScreen(viewModel: viewModel))
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

// PLACEHOLDER PREVIEW — uses an existing `SharingScreen` case and existing string
// keys purely so the layout renders. Real failure screens get their own
// SharingScreen case and copy per follow-up ticket.
#Preview("Two buttons") {
    FailureScreenPreview(
        viewModel: ResolutionFailureViewModel(
            screen: .error,
            bodyKey: "PLACEHOLDER_failureBody",
            buttons: [
                FailureButton(
                    titleKey: "goBackToDocumentsButton",
                    event: .goBackToDocumentsButton,
                    accessibilityIdentifier: "failure-preview-primary",
                    action: {}
                ),
                FailureButton(
                    titleKey: "cancel",
                    event: .cancel,
                    accessibilityIdentifier: "failure-preview-secondary",
                    action: {}
                )
            ]
        )
    )
    .ignoresSafeArea()
}

#Preview("One button") {
    FailureScreenPreview(
        viewModel: ResolutionFailureViewModel(
            screen: .error,
            bodyKey: "PLACEHOLDER_failureBody",
            buttons: [
                FailureButton(
                    titleKey: "goBackToDocumentsButton",
                    event: .goBackToDocumentsButton,
                    accessibilityIdentifier: "failure-preview-primary",
                    action: {}
                )
            ]
        )
    )
    .ignoresSafeArea()
}
#endif
