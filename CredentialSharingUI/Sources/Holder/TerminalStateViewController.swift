import DesignSystem
import UIKit

/// A terminal view model that wants a non-default gap beneath its movable
/// footer. `GDSScreen` applies a fixed 16pt bottom margin to the footer stack,
/// which can make a single pinned button look like it is floating; conforming
/// view models can tighten (or remove) that gap.
@MainActor
protocol TerminalFooterInsetProviding {
    /// Desired bottom inset (points) beneath the movable footer. `nil` keeps the
    /// `GDSScreen` default.
    var footerBottomInset: CGFloat? { get }
}

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
    /// Accessibility identifier `GDSScreen` assigns to its movable-footer stack.
    private static let footerStackIdentifier = "gds-screen-bottom-stack-view"

    /// Convenience initialiser for a plain, title-only terminal screen (e.g. the
    /// "Unfulfillable request" empty-response path). Builds a minimal centred
    /// view model so callers that only have a message do not need to construct
    /// one themselves.
    convenience init(message: String) {
        self.init(viewModel: TerminalStateMessageViewModel(message: message))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyFooterBottomInsetIfNeeded()
    }

    /// `GDSScreen` hard-codes a 16pt bottom margin on its footer stack and
    /// exposes neither the stack nor the value, so a view model that wants a
    /// different gap is honoured here by locating the stack (by its
    /// accessibility identifier) and overriding its bottom layout margin.
    private func applyFooterBottomInsetIfNeeded() {
        guard let inset = (viewModel as? TerminalFooterInsetProviding)?.footerBottomInset,
              let footerStack = firstSubview(
                  of: view,
                  withAccessibilityIdentifier: Self.footerStackIdentifier
              ) as? UIStackView,
              footerStack.directionalLayoutMargins.bottom != inset else {
            return
        }
        footerStack.directionalLayoutMargins.bottom = inset
    }

    private func firstSubview(
        of root: UIView,
        withAccessibilityIdentifier identifier: String
    ) -> UIView? {
        if root.accessibilityIdentifier == identifier { return root }
        for subview in root.subviews {
            if let match = firstSubview(of: subview, withAccessibilityIdentifier: identifier) {
                return match
            }
        }
        return nil
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
