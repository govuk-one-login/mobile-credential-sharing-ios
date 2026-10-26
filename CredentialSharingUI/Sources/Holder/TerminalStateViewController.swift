import DesignSystem
import UIKit

/// Generic terminal screen for the holder journey.
///
/// Terminal screens (success / "details shared", empty-or-unfulfillable
/// response, errors) share the same centre-aligned `GDSScreen` base, so rather
/// than duplicating a view controller per outcome each caller supplies its own
/// ``GDSScreenViewModel`` (for example `DetailsSharedViewModel`). The view model
/// owns the icon, copy, buttons and analytics; this view controller only hosts
/// it. `HolderContainerNavigation` recognises this type to suppress the Cancel
/// bar button and allow the sheet to be dismissed.
@MainActor
final class TerminalStateViewController: GDSScreen {
    /// Convenience initialiser for a plain, title-only terminal screen (e.g. the
    /// "Unfulfillable request" empty-response path). Builds a minimal centred
    /// view model so callers that only have a message do not need to construct
    /// one themselves.
    convenience init(message: String) {
        self.init(viewModel: TerminalStateMessageViewModel(message: message))
    }
}

// MARK: - TerminalStateMessageViewModel

/// Minimal centred view model for a title-only terminal screen.
@MainActor
struct TerminalStateMessageViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .centred
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel] = []
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action? = nil
    let didDismiss: DesignSystem.Action? = nil

    init(message: String) {
        self.body = [
            GDSTextViewModel(
                title: GDSLocalisedString(stringLiteral: message),
                titleFont: DesignSystem.Font.Base.title2,
                alignment: .center,
                accessibilityTraits: .header,
                accessibilityIdentifier: "TerminalStateLabel",
                verticalPadding: .vertical(DesignSystem.Spacing.default)
            )
        ]
    }
}
