import Foundation

/// Unambiguous accessor for this module's resource bundle.
///
/// Tests that `@testable import` both `CredentialSharingUI` and `DesignSystem`
/// cannot use the leading-dot `.module` form because each module synthesises its
/// own `Bundle.module`, which makes the reference ambiguous. This accessor gives
/// those tests a single, module-qualified way to reach the CredentialSharingUI
/// resource bundle.
enum CredentialSharingUIResources {
    static var bundle: Bundle { .module }
}
