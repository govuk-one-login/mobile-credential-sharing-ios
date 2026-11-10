import Foundation

/// Exposes the `CredentialSharingUI` resource bundle to call sites outside the
/// module (e.g. the app's analytics adapter), so screen `titleKey`s resolve
/// against the UI module's `Localizable.xcstrings`.
///
/// This stays in `CredentialSharingUI` because `.module` resolves to the
/// bundle of the module it is compiled in; the analytics protocol and enums
/// live in `SharingOrchestration`.
public enum SharingBundle {
    public static var module: Bundle { .module }
}
