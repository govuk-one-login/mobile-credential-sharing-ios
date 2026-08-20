import Foundation
import SharingOrchestration

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

/// Error thrown when the user cancels local authentication.
/// Conforms to `LocalAuthCancelled` so the SDK keeps the session active.
enum MockLocalAuthCancelledError: LocalAuthCancelled {
    case cancelled
}

/// Error thrown when signing fails fatally.
/// Conforms to `SignError` so the SDK sends an encrypted termination response.
enum MockSignFailedError: SignError {
    case signingFailed
}
