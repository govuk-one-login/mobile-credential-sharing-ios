import Foundation
import Testing

/// Polls a condition at short intervals until it returns `true` or the timeout expires.
///
/// Use this instead of `Task.sleep` when waiting for async state transitions in tests.
/// It makes tests deterministic: they pass as soon as the condition is met and only
/// fail after a generous timeout, eliminating flakiness caused by CI resource pressure.
///
/// Uses `DispatchQueue.main.asyncAfter` for yielding, which ensures the main run loop
/// processes pending work (including Task continuations from production code) between polls.
///
/// - Parameters:
///   - timeout: Maximum time to wait for the condition (default 5 seconds).
///   - pollInterval: Time between polls in seconds (default 0.01s / 10ms).
///   - description: Optional description shown on failure.
///   - condition: A closure that returns `true` when the expected state has been reached.
@MainActor
func eventually(
    timeout: TimeInterval = 5,
    pollInterval: TimeInterval = 0.01,
    _ description: String = "Condition was not met within timeout",
    condition: @MainActor () -> Bool
) async {
    let deadline = Date.now.addingTimeInterval(timeout)
    while Date.now < deadline {
        if condition() { return }
        // Yield first to give pending @MainActor Tasks a chance to execute
        await Task.yield()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
                continuation.resume()
            }
        }
    }
    Issue.record(Comment(rawValue: description))
}
