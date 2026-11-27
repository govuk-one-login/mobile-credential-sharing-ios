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
    /// The primary button is GDSCommon's `RoundedButton`, which has a fixed 15pt
    /// corner radius. It's given fully rounded (capsule) corners to match the
    /// DesignSystem `GDSButton` primary style used elsewhere in the journey.
    ///
    /// - Note: This relies on the component's accessibility identifiers. If they
    ///   are renamed the overrides are skipped (and logged), and the screen falls
    ///   back to the component's default behaviour.
    static func resolutionFailure(viewModel: ResolutionFailureViewModel) -> GDSErrorScreen {
        let screen = GDSErrorScreen(viewModel: viewModel)
        screen.loadViewIfNeeded()

        if let element = screen.view.firstDescendant(withAccessibilityIdentifier: iconTitleElementIdentifier) {
            element.accessibilityLabel = ErrorScreenVoiceOverLabel.make(
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
                if index == 0 {
                    button.applyCapsuleCorners()
                }
                button.accessibilityIdentifier = identifier
            } else {
                Logger.log("GDSErrorScreen button \(index) not found — identifier '\(identifier)' not applied", level: .error)
            }
        }

        return screen
    }
}

/// Builds the VoiceOver label for the error screen's grouped icon + title element.
private final class ErrorScreenVoiceOverLabel {
    /// Builds the label as "<prefix>: <title>" (e.g. "Error: Sharing is
    /// currently unavailable"), reusing the component's own localised prefix.
    ///
    /// The component's label is "<prefix>: <title> :", so the prefix is whatever
    /// precedes the title. If the title can't be found, the title alone is used.
    static func make(title: String, componentLabel: String?) -> String {
        guard let componentLabel,
              let titleRange = componentLabel.range(of: title) else {
            return title
        }
        return String(componentLabel[..<titleRange.lowerBound]) + title
    }
}

/// Keeps a view's corner radius at half its height, so it stays a capsule as
/// Dynamic Type or rotation changes the height.
private final class CapsuleCornerObserver: NSObject {
    private var observation: NSKeyValueObservation?

    init(layer: CALayer) {
        super.init()
        observation = layer.observe(\.bounds, options: [.initial, .new]) { layer, _ in
            layer.cornerRadius = layer.bounds.height / 2
        }
    }
}

private extension UIView {
    private static var capsuleObserverKey: UInt8 = 0

    func applyCapsuleCorners() {
        layer.cornerCurve = .continuous
        let observer = CapsuleCornerObserver(layer: layer)
        objc_setAssociatedObject(self, &Self.capsuleObserverKey, observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

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
