import Foundation

/// Presentation payload for a resolved Holder journey.
///
/// The UI (`ResolutionViewController`) selects localised text and success/error
/// styling from `result`, then calls the orchestrator to dismiss once the user
/// acknowledges. A `nil` `result` means immediate dismissal (consent denied or
/// transaction cancelled); component errors and raw diagnostics stay internal.
public struct ResolutionPresentation: Equatable, Hashable, Sendable {
    public let result: ResolutionResult?

    public init(result: ResolutionResult?) {
        self.result = result
    }
}

/// The user-facing outcome of a resolved journey.
public enum ResolutionResult: Equatable, Hashable, Sendable {
    /// Confirmation screen awaiting dismissal — the Holder's response was sent.
    case detailsShared
    /// Error explanation awaiting dismissal — nothing matched the request.
    case unfulfillableRequest
    /// Error explanation awaiting dismissal for a terminal failure.
    /// - `category` selects which screen is rendered.
    /// - `errorDescription` is the low-level `SessionError.errorDescription`, used
    ///   for analytics `error_reason` only. It is never shown to the user.
    case failed(FailureCategory, errorDescription: String)
}

/// User-facing failure buckets. Internal `SessionError` values are mapped down
/// to these for display; raw diagnostics are not surfaced.
public enum FailureCategory: Equatable, Hashable, Sendable {
    case connectionInterrupted
    case requestCannotBeUsed
    case credentialUnavailable
    case secureSharingCouldNotComplete
    case unexpectedProblem
    /// Catch-all for failures with no dedicated error screen.
    case generic
    
    // TODO: DCMAW-24162 Remove once each `SessionError` has been migrated to a dedicated category and screen.
    /// Transitional: a failure that has not yet been migrated to its own
    /// resolution failure screen. Carries the original `SessionError` so the
    /// legacy `ErrorViewController` renders exactly as it did before.
    case legacy(SessionError)

    // TODO: DCMAW-24152, DCMAW-24154 Move errors off `.legacy` as their dedicated screens land.
    /// Maps an internal `SessionError` to the category used to render it.
    /// Only `.generic(String)` and `.unknown` use the generic error screen; every
    /// other error stays on its existing screen via `.legacy`.
    init(_ error: SessionError) {
        switch error {
        case .generic, .unknown:
            self = .generic
        default:
            self = .legacy(error)
        }
    }
}
