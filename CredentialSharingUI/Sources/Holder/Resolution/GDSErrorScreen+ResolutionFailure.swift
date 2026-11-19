import GDSCommon
import SharingLogging
import UIKit

extension GDSErrorScreen {
    /// The accessibility identifier `GDSErrorScreen` gives its grouped icon + title element.
    private static let iconTitleElementIdentifier = "error-screen-icon-title-stack-view"
    /// The accessibility identifier `GDSErrorScreen` gives its decorative icon.
    private static let iconIdentifier = "error-screen-image"

    /// The accessibility identifier `GDSErrorScreen` gives the button at `index`.
    private static func buttonIdentifier(at index: Int) -> String {
        "error-screen-button-\(index)"
    }

    /// Builds a `GDSErrorScreen` for a resolution failure, with VoiceOver reading
    /// the prefix and title only (e.g. "Error: <title>").
    ///
    /// `GDSErrorScreen` groups the icon and title into a single accessibility
    /// element labelled "<icon prefix>: <title> :", where the prefix (e.g. "Error")
    /// comes from `ErrorScreenImage`. The component can't be subclassed from
    /// outside GDSCommon, so we load the view and replace that element's label,
    /// keeping the localised prefix and dropping the trailing " :".
    ///
    /// The icon is decorative, so it is also hidden from accessibility. Otherwise
    /// VoiceOver's Image Descriptions can describe the symbol (e.g. "night sky,
    /// thermometer") after the title.
    ///
    /// Each button's generic `error-screen-button-<index>` identifier is replaced
    /// with the screen-specific one from the view model, for UI tests.
    ///
    /// - Note: This relies on the component's accessibility identifiers. If they
    ///   are renamed the overrides are skipped (and logged), and the screen falls
    ///   back to the component's default behaviour.
    static func resolutionFailure(viewModel: ResolutionFailureViewModel) -> GDSErrorScreen {
        let screen = GDSErrorScreen(viewModel: viewModel)
        screen.loadViewIfNeeded()

        if let element = screen.view.firstDescendant(withAccessibilityIdentifier: iconTitleElementIdentifier) {
            element.accessibilityLabel = voiceOverLabel(
                title: viewModel.title.value,
                componentLabel: element.accessibilityLabel
            )
        } else {
            Logger.log("GDSErrorScreen icon/title element not found — VoiceOver label not overridden", level: .error)
        }

        if let icon = screen.view.firstDescendant(withAccessibilityIdentifier: iconIdentifier) {
            icon.isAccessibilityElement = false
            icon.accessibilityElementsHidden = true
            icon.accessibilityTraits = .none
        } else {
            Logger.log("GDSErrorScreen icon not found — icon not hidden from VoiceOver", level: .error)
        }

        for (index, identifier) in viewModel.buttonAccessibilityIdentifiers.enumerated() {
            if let button = screen.view.firstDescendant(withAccessibilityIdentifier: buttonIdentifier(at: index)) {
                button.accessibilityIdentifier = identifier
            } else {
                Logger.log("GDSErrorScreen button \(index) not found — identifier '\(identifier)' not applied", level: .error)
            }
        }

        return screen
    }
}

/// Builds the VoiceOver label as "<prefix>: <title>" (e.g. "Error: Sharing is
/// currently unavailable"), reusing the component's own localised prefix.
///
/// The component's label is "<prefix>: <title> :", so the prefix is whatever
/// precedes the title. If the title can't be found, the title alone is used.
private func voiceOverLabel(title: String, componentLabel: String?) -> String {
    guard let componentLabel,
          let titleRange = componentLabel.range(of: title) else {
        return title
    }
    return String(componentLabel[..<titleRange.lowerBound]) + title
}

private extension UIView {
    func firstDescendant(withAccessibilityIdentifier identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier { return self }
        for subview in subviews {
            if let match = subview.firstDescendant(withAccessibilityIdentifier: identifier) {
                return match
            }
        }
        return nil
    }
}
