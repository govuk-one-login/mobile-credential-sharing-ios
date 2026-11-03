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
    /// Localised error explanation awaiting dismissal for a terminal failure.
    case failed(FailureCategory)
}

/// User-facing failure buckets. Internal `SessionError` values are mapped down
/// to these for display; raw diagnostics are not surfaced.
public enum FailureCategory: Equatable, Hashable, Sendable {
    case connectionInterrupted
    case requestCannotBeUsed
    case credentialUnavailable
    case secureSharingCouldNotComplete
    case unexpectedProblem
}
