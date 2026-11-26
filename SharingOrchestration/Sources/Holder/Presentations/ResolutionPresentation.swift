import Foundation

/// Presentation payload for a resolved Holder journey, carried by both terminal
/// states: `HolderSessionState.success(presentation:)` and
/// `HolderSessionState.failed(presentation:)`.
///
/// The orchestrator builds this; the UI only reads `result` to choose a screen,
/// then calls the orchestrator to finish once the user acknowledges it:
/// - `.success` is rendered by `ResolutionViewController` (`.detailsShared`,
///   `.unfulfillableRequest`). A `nil` `result` means immediate dismissal, e.g.
///   consent denied or transaction cancelled.
/// - `.failed` is rendered by `HolderNavigationController` (see
///   `HolderNavigationController+Failure.swift`), which switches on the
///   ``FailureCategory``: migrated categories show a `GDSScreen` built from
///   `ResolutionFailureViewModel`; `.legacy` shows the old `ErrorViewController`.
///
/// Component errors stay internal: the UI never sees a raw `SessionError` except
/// through the transitional ``FailureCategory/legacy(_:)`` case.
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
    /// Error screen awaiting dismissal for a terminal failure.
    /// - `category` selects which screen is rendered.
    /// - `errorDescription` is the low-level `SessionError.errorDescription`, sent
    ///   as the analytics `reason` (`error_reason`) only. It is never shown to the user.
    ///
    /// Built from a `SessionError` by `HolderSessionState.failed(_:)`, so
    /// orchestrator call sites can keep raising `.failed(<SessionError>)`.
    case failed(FailureCategory, errorDescription: String)
}

/// User-facing failure buckets. Internal `SessionError` values are mapped down
/// to these by ``init(_:)``, which is the single place that decides which error
/// gets which screen. Raw diagnostics are not surfaced.
///
/// To migrate an error to its own screen: map it to a category here, then give
/// that category its own case in `HolderNavigationController.showFailure`.
/// Until then, `.connectionInterrupted` … `.unexpectedProblem` are unused and
/// fall back to the generic screen if they are ever raised.
public enum FailureCategory: Equatable, Hashable, Sendable {
    case connectionInterrupted
    case requestCannotBeUsed
    case credentialUnavailable
    case secureSharingCouldNotComplete
    case unexpectedProblem
    /// The ReaderAuth COSE check failed: "The app that the person doing the check is
    /// using does not currently meet all of our security requirements".
    case readerAuthentication
    /// The user turned off the device's Bluetooth during the session.
    case bluetoothTurnedOff
    /// Catch-all "Sharing is currently unavailable" screen, for failures with no
    /// dedicated error screen.
    case generic
    
    // TODO: DCMAW-17154 Remove once each `SessionError` has been migrated to a dedicated category and screen.
    /// Transitional: a failure that has not yet been migrated to its own
    /// resolution failure screen. Carries the original `SessionError` so the
    /// legacy `ErrorViewController` renders exactly as it did before.
    case legacy(SessionError)

    // TODO: DCMAW-24154 Move errors off `.legacy` as their dedicated screens land.
    /// Maps an internal `SessionError` to the category used to render it.
    /// `.generic(String)` and `.unknown` use the generic error screen,
    /// `.readerAuthenticationFailed` uses the ReaderAuth error screen,
    /// `.bluetoothTurnedOff` uses the Bluetooth-off error screen; every
    /// other error stays on its existing screen via `.legacy`.
    init(_ error: SessionError) {
        switch error {
        case .generic, .unknown:
            self = .generic
        case .readerAuthenticationFailed:
            self = .readerAuthentication
        case .bluetoothTurnedOff:
            self = .bluetoothTurnedOff
        default:
            self = .legacy(error)
        }
    }
}
