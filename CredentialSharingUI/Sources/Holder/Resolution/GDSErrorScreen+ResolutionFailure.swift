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
    /// only the title.
    ///
    /// `GDSErrorScreen` groups the icon and title into a single accessibility
    /// element labelled "<icon prefix>: <title> :", where the prefix (e.g. "Error")
    /// comes from `ErrorScreenImage` and cannot be removed through the view model.
    /// The component can't be subclassed from outside GDSCommon, so we load the
    /// view and replace that element's label with the title alone.
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
            element.accessibilityLabel = viewModel.title.value
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
