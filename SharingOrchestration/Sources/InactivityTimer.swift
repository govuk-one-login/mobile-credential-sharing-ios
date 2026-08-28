import Foundation
import SharingLogger

/// Protocol for the inactivity timer to enable mocking in tests.
@MainActor
public protocol InactivityTimerProtocol {
    /// Starts the inactivity countdown. Must be called once when the connection is established.
    func start()
    /// Resets the countdown to the full duration. No-op if the timer is not running.
    func reset()
    /// Stops the timer. No further callbacks will fire until `start()` is called again.
    func stop()
}

/// A timer that fires a callback after a configurable period of BLE inactivity.
///
/// The timer uses structured concurrency (`Clock.sleep`) and runs on the main actor.
/// It is designed to be started once when a BLE connection is established, reset on
/// each inbound or outbound BLE event, and stopped when the session is torn down.
///
/// Generic over `Clock` to support deterministic testing with a controllable clock.
@MainActor
public final class InactivityTimer<C: Clock>: InactivityTimerProtocol
where C.Duration == Duration {
    public static var defaultTimeout: Duration { .seconds(300) }

    public let duration: Duration
    private let clock: C
    private let onTimeout: @MainActor () -> Void
    private var timerTask: Task<Void, Never>?

    public init(
        duration: Duration = InactivityTimer.defaultTimeout,
        clock: C,
        onTimeout: @escaping @MainActor () -> Void
    ) {
        self.duration = duration
        self.clock = clock
        self.onTimeout = onTimeout
    }

    public func start() {
        Logger.log("Inactivity timer started")
        scheduleNewCountdown()
    }

    public func reset() {
        guard timerTask != nil else { return }
        Logger.log("Inactivity timer reset")
        scheduleNewCountdown()
    }

    public func stop() {
        Logger.log("Inactivity timer stopped")
        timerTask?.cancel()
        timerTask = nil
    }

    private func scheduleNewCountdown() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [duration, clock, onTimeout] in
            do {
                try await clock.sleep(for: duration)
                guard !Task.isCancelled else { return }
                onTimeout()
            } catch {
                // CancellationError — expected on reset/stop
            }
        }
    }
}

/// Convenience extension for production use with `ContinuousClock`.
public extension InactivityTimer where C == ContinuousClock {
    convenience init(
        duration: Duration = InactivityTimer.defaultTimeout,
        onTimeout: @escaping @MainActor () -> Void
    ) {
        self.init(duration: duration, clock: ContinuousClock(), onTimeout: onTimeout)
    }
}
