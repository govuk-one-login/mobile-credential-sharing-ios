import Foundation
import Testing

/// Polls a condition at short intervals until it returns `true` or the timeout expires.
///
/// Use this instead of `Task.sleep` when waiting for async state transitions in tests.
/// It makes tests deterministic: they pass as soon as the condition is met and only
/// fail after a generous timeout, eliminating flakiness caused by CI resource pressure.
///
/// - Parameters:
///   - timeout: Maximum time to wait for the condition (default 2 seconds).
///   - pollInterval: How often to re-evaluate the condition (default 10ms).
///   - description: Optional description shown on failure.
///   - condition: A closure that returns `true` when the expected state has been reached.
@MainActor
func eventually(
    timeout: Duration = .seconds(2),
    pollInterval: Duration = .milliseconds(10),
    _ description: String = "Condition was not met within timeout",
    condition: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: pollInterval)
    }
    Issue.record(Comment(rawValue: description))
}
