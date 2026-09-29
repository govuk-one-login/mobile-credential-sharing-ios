import Foundation

/// Error thrown when Reader Authentication fails during processing.
///
/// Carries a stable ``ReaderAuthenticationReason`` and, optionally, the
/// underlying error that triggered the failure (for logging and diagnostics).
/// Mirrors the Android `ReaderAuthenticationFailure` exception.
public struct ReaderAuthenticationFailure: Error, Equatable {

    /// The stable reason identifier for this failure.
    public let reason: ReaderAuthenticationReason

    /// A human-readable message describing the failure.
    public var message: String {
        "Reader Authentication failed with reason: \(reason)"
    }

    /// The underlying error that caused this failure, if any.
    public let cause: (any Error)?

    public init(reason: ReaderAuthenticationReason, cause: (any Error)? = nil) {
        self.reason = reason
        self.cause = cause
    }

    /// Equality is defined by ``reason`` only. The optional ``cause`` is a
    /// diagnostic aid and is not part of the value's identity, matching how
    /// callers branch on the reason rather than the underlying error.
    public static func == (
        lhs: ReaderAuthenticationFailure,
        rhs: ReaderAuthenticationFailure
    ) -> Bool {
        lhs.reason == rhs.reason
    }
}
