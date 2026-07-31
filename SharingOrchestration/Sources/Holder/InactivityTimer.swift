import Foundation

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
/// The timer uses structured concurrency (`Task.sleep`) and runs on the main actor.
/// It is designed to be started once when a BLE connection is established, reset on
/// each inbound or outbound BLE event, and stopped when the session is torn down.
@MainActor
public final class InactivityTimer: InactivityTimerProtocol {
    public static let defaultTimeout: TimeInterval = 300

    private let duration: TimeInterval
    private let onTimeout: @MainActor () -> Void
    private var timerTask: Task<Void, Never>?

    public init(
        duration: TimeInterval = InactivityTimer.defaultTimeout,
        onTimeout: @escaping @MainActor () -> Void
    ) {
        self.duration = duration
        self.onTimeout = onTimeout
    }

    public func start() {
        scheduleNewCountdown()
    }

    public func reset() {
        guard timerTask != nil else { return }
        scheduleNewCountdown()
    }

    public func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func scheduleNewCountdown() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [duration, onTimeout] in
            do {
                try await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                onTimeout()
            } catch {
                // CancellationError — expected on reset/stop
            }
        }
    }
}
