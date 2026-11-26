import DesignSystem
import SharingLogging
import UIKit

/// Renders a `ResolutionFailureViewModel`. All failure screens share it; only the
/// view model differs.
///
/// A thin `GDSScreen` subclass so the screen can be identified (e.g. in navigation
/// tests), its view model is available as the concrete type, and the decorative
/// icon can be hidden from VoiceOver.
@MainActor
final class ResolutionFailureViewController: GDSScreen {
    /// The accessibility identifier `GDSErrorIconTitle` gives its decorative icon.
    private static let iconIdentifier = "error-screen-icon"

    let failureViewModel: ResolutionFailureViewModel

    init(viewModel: ResolutionFailureViewModel) {
        self.failureViewModel = viewModel
        super.init(viewModel: viewModel)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hideIconFromVoiceOver()
    }

    /// `GDSErrorIconTitle` groups the icon and title into one "Error: <title>"
    /// element and marks the icon as not an accessibility element, but VoiceOver's
    /// Image Descriptions can still describe the symbol and append it to that label
    /// (e.g. "Error: <title>: night sky, thermometer"). Hiding the icon's
    /// accessibility elements stops that.
    ///
    /// - Note: This relies on the component's icon identifier. If it is renamed the
    ///   override is skipped (and logged) and the component's default behaviour applies.
    private func hideIconFromVoiceOver() {
        guard let icon = view.firstDescendant(withAccessibilityIdentifier: Self.iconIdentifier) else {
            Logger.log("Failure screen icon not found — icon not hidden from VoiceOver", level: .error)
            return
        }
        icon.isAccessibilityElement = false
        icon.accessibilityElementsHidden = true
        icon.accessibilityTraits = .none
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
