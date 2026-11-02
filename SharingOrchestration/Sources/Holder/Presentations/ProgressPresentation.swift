import Foundation

/// Describes a holder progress (loading) screen.
///
/// Carries the copy/analytics variant to render and the cancellation status so
/// the progress screen can decide whether to surface a Cancel control and, if
/// so, whether tapping it requires confirmation — mirroring the other holder
/// presentation objects (``ReadinessPresentation``, ``EngagementPresentation``).
public struct ProgressPresentation: Equatable, Hashable, Sendable {

    /// The distinct progress screens in the holder journey. Each maps to its own
    /// copy and analytics screen identifier.
    public enum ProgressPhase: Equatable, Hashable, Sendable {
        /// Shown while establishing the connection and fetching the request
        /// ("Getting list of details"). Cancellable.
        case processingRequest
        /// Shown while sending the response ("Sharing your details"). Not cancellable.
        case sendingResponse
    }

    public let phase: ProgressPhase

    /// Cancellation status for this screen:
    /// - `nil`  — no Cancel control is offered.
    /// - `false` — Cancel is offered and cancels immediately.
    /// - `true`  — Cancel is offered and requires confirmation first.
    public let cancelRequiresConfirmation: Bool?

    public init(
        phase: ProgressPhase,
        cancelRequiresConfirmation: Bool?
    ) {
        self.phase = phase
        self.cancelRequiresConfirmation = cancelRequiresConfirmation
    }
}
