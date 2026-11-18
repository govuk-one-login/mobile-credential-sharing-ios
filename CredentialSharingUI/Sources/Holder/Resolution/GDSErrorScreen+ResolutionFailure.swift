import GDSCommon
import SharingLogging
import UIKit

extension GDSErrorScreen {
    /// The accessibility identifier `GDSErrorScreen` gives its grouped icon + title element.
    private static let iconTitleElementIdentifier = "error-screen-icon-title-stack-view"
    /// The accessibility identifier `GDSErrorScreen` gives its decorative icon.
    private static let iconIdentifier = "error-screen-image"

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
    /// - Note: This relies on the component's accessibility identifiers. If they
    ///   are renamed the overrides are skipped (and logged), and VoiceOver falls
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
