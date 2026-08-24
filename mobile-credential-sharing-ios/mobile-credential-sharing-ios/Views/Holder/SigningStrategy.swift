import Foundation

/// Defines the signing behaviour used by `MockCredentialProvider` when `sign()` is called.
/// This allows the test app to simulate different failure scenarios without requiring
/// the host app or real local-authentication prompts.
enum SigningStrategy: Sendable, Equatable {
    /// Signs normally using the credential's private key.
    case success
    /// Every call to `sign()` throws a fatal signing error.
    case alwaysFail
    /// The first call to `sign()` throws a localAuthenticationCancelled error;
    /// subsequent calls sign normally.
    case failOnceThenSucceed
}

/// Error thrown when the signing-failure strategy is active.
enum MockSigningError: Error, Equatable, LocalizedError {
    /// Simulates a fatal, unrecoverable signing failure.
    case signingFailed
    /// Simulates the user cancelling local authentication (e.g. biometric prompt).
    case localAuthenticationCancelled

    var errorDescription: String? {
        switch self {
        case .signingFailed:
            return "Mock signing failed: fatal signing error (unrecoverable)"
        case .localAuthenticationCancelled:
            return "Mock signing failed: local authentication cancelled by user"
        }
    }
}
