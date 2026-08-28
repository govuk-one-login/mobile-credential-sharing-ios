import Foundation

/// Errors the Host App returns from `CredentialProvider.sign()`.
///
/// The Host App catches its internal errors and maps them to one of these cases.
/// Typed throws ensures no other error type can propagate.
public enum CredentialSigningError: Error, Equatable, Sendable {
    /// The user explicitly cancelled the authentication prompt.
    /// The session stays active and the user can retry.
    case recoverable

    /// Any other condition prevented signing.
    /// The SDK terminates the session.
    case unrecoverable
}
