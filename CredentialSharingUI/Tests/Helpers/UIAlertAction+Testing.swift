import UIKit

extension UIAlertAction {
    /// Invokes the action's handler block, enabling unit tests to simulate button taps
    /// on a `UIAlertController` without requiring a full XCUITest.
    @MainActor
    func simulateTap() {
        typealias Handler = @convention(block) (UIAlertAction) -> Void
        guard let block = value(forKey: "handler") else { return }
        let handler = unsafeBitCast(block as AnyObject, to: Handler.self)
        handler(self)
    }
}
