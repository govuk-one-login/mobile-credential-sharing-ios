import Foundation
import SharingOrchestration

/// Defines the signing behaviour used by `MockCredentialProvider` when `sign()` is called.
/// This allows the test app to simulate different failure scenarios without requiring
/// the host app or real local-authentication prompts.
enum SigningStrategy: Sendable, Equatable {
    /// Signs normally using the credential's private key.
    case success
    /// Every call to `sign()` throws `.unrecoverable`.
    case alwaysFail
    /// The first call to `sign()` throws `.recoverable`;
    /// subsequent calls sign normally.
    case failOnceThenSucceed
}

