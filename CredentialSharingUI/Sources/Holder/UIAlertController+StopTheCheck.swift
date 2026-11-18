import DesignSystem
import UIKit

extension UIAlertController {
    /// Styles the "Stop the check" body per design (centred body font in the
    /// primary text colour, with a line of space beneath) for the given traits.
    func setStopTheCheckBody(_ body: String, traitCollection: UITraitCollection) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection),
            .foregroundColor: DesignSystem.Color.Text.primary,
            .paragraphStyle: paragraphStyle
        ]

        // The trailing line break adds one line of space under the body.
        setValue(
            NSAttributedString(string: body + "\n", attributes: attributes),
            forKey: "attributedMessage"
        )
    }
}
